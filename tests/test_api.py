"""
CarePlix WoundOS – Test Suite
Uses an in-memory SQLite database so tests are fast and isolated.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

# ─── In-memory test database ──────────────────────────────────────────────
# StaticPool ensures all connections share the same in-memory SQLite DB.

TEST_DB_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DB_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_database():
    """Create tables before each test and drop them after."""
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()


@pytest.fixture()
def client():
    return TestClient(app)


# ─── Fixtures ─────────────────────────────────────────────────────────────

PATIENT_PAYLOAD = {
    "first_name": "Jane",
    "last_name": "Doe",
    "date_of_birth": "1985-06-15",
    "gender": "female",
    "mrn": "MRN001",
    "phone": "+1-555-0100",
    "email": "jane.doe@example.com",
}

WOUND_PAYLOAD_BASE = {
    "wound_type": "pressure_ulcer",
    "location": "Left heel",
    "stage": "stage_2",
    "description": "Partial thickness skin loss",
}

ASSESSMENT_PAYLOAD_BASE = {
    "assessed_by": "Dr. Smith",
    "length_cm": 3.5,
    "width_cm": 2.0,
    "depth_cm": 0.5,
    "area_cm2": 7.0,
    "wound_bed": "granulation",
    "exudate_amount": "moderate",
    "healing_status": "improving",
    "pain_score": 4,
    "notes": "Wound showing improvement",
    "treatment_plan": "Continue current dressing",
}


def create_patient(client):
    r = client.post("/patients/", json=PATIENT_PAYLOAD)
    assert r.status_code == 201
    return r.json()


def create_wound(client, patient_id):
    payload = {**WOUND_PAYLOAD_BASE, "patient_id": patient_id}
    r = client.post("/wounds/", json=payload)
    assert r.status_code == 201
    return r.json()


def create_assessment(client, wound_id):
    payload = {**ASSESSMENT_PAYLOAD_BASE, "wound_id": wound_id}
    r = client.post("/assessments/", json=payload)
    assert r.status_code == 201
    return r.json()


# ═══════════════════════════════════════════════════════════════════════════
# Health check
# ═══════════════════════════════════════════════════════════════════════════

def test_health_check(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


# ═══════════════════════════════════════════════════════════════════════════
# Patient CRUD
# ═══════════════════════════════════════════════════════════════════════════

class TestPatients:
    def test_list_patients_empty(self, client):
        r = client.get("/patients/")
        assert r.status_code == 200
        assert r.json() == []

    def test_create_patient(self, client):
        r = client.post("/patients/", json=PATIENT_PAYLOAD)
        assert r.status_code == 201
        data = r.json()
        assert data["first_name"] == "Jane"
        assert data["mrn"] == "MRN001"
        assert "id" in data

    def test_create_duplicate_mrn(self, client):
        client.post("/patients/", json=PATIENT_PAYLOAD)
        r = client.post("/patients/", json=PATIENT_PAYLOAD)
        assert r.status_code == 409

    def test_get_patient(self, client):
        p = create_patient(client)
        r = client.get(f"/patients/{p['id']}")
        assert r.status_code == 200
        assert r.json()["id"] == p["id"]

    def test_get_patient_not_found(self, client):
        r = client.get("/patients/9999")
        assert r.status_code == 404

    def test_update_patient(self, client):
        p = create_patient(client)
        r = client.put(f"/patients/{p['id']}", json={"first_name": "Janet"})
        assert r.status_code == 200
        assert r.json()["first_name"] == "Janet"

    def test_delete_patient(self, client):
        p = create_patient(client)
        r = client.delete(f"/patients/{p['id']}")
        assert r.status_code == 204
        assert client.get(f"/patients/{p['id']}").status_code == 404

    def test_patient_without_mrn(self, client):
        payload = {**PATIENT_PAYLOAD, "mrn": None}
        del payload["mrn"]
        r = client.post("/patients/", json=payload)
        assert r.status_code == 201


# ═══════════════════════════════════════════════════════════════════════════
# Wound CRUD
# ═══════════════════════════════════════════════════════════════════════════

class TestWounds:
    def test_create_wound(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        assert w["wound_type"] == "pressure_ulcer"
        assert w["patient_id"] == p["id"]

    def test_create_wound_unknown_patient(self, client):
        payload = {**WOUND_PAYLOAD_BASE, "patient_id": 9999}
        r = client.post("/wounds/", json=payload)
        assert r.status_code == 404

    def test_list_wounds_by_patient(self, client):
        p = create_patient(client)
        create_wound(client, p["id"])
        create_wound(client, p["id"])
        r = client.get(f"/wounds/?patient_id={p['id']}")
        assert r.status_code == 200
        assert len(r.json()) == 2

    def test_get_wound_with_assessments(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        create_assessment(client, w["id"])
        r = client.get(f"/wounds/{w['id']}")
        assert r.status_code == 200
        assert len(r.json()["assessments"]) == 1

    def test_update_wound(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        r = client.put(f"/wounds/{w['id']}", json={"stage": "stage_3"})
        assert r.status_code == 200
        assert r.json()["stage"] == "stage_3"

    def test_delete_wound(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        r = client.delete(f"/wounds/{w['id']}")
        assert r.status_code == 204
        assert client.get(f"/wounds/{w['id']}").status_code == 404

    def test_cascade_delete_with_patient(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        client.delete(f"/patients/{p['id']}")
        assert client.get(f"/wounds/{w['id']}").status_code == 404


# ═══════════════════════════════════════════════════════════════════════════
# Assessment CRUD
# ═══════════════════════════════════════════════════════════════════════════

class TestAssessments:
    def test_create_assessment(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        a = create_assessment(client, w["id"])
        assert a["assessed_by"] == "Dr. Smith"
        assert a["area_cm2"] == 7.0
        assert a["healing_status"] == "improving"

    def test_create_assessment_invalid_wound(self, client):
        payload = {**ASSESSMENT_PAYLOAD_BASE, "wound_id": 9999}
        r = client.post("/assessments/", json=payload)
        assert r.status_code == 404

    def test_invalid_pain_score(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        payload = {**ASSESSMENT_PAYLOAD_BASE, "wound_id": w["id"], "pain_score": 11}
        r = client.post("/assessments/", json=payload)
        assert r.status_code == 422

    def test_list_assessments_by_wound(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        create_assessment(client, w["id"])
        create_assessment(client, w["id"])
        r = client.get(f"/assessments/?wound_id={w['id']}")
        assert r.status_code == 200
        assert len(r.json()) == 2

    def test_get_assessment(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        a = create_assessment(client, w["id"])
        r = client.get(f"/assessments/{a['id']}")
        assert r.status_code == 200
        assert r.json()["id"] == a["id"]

    def test_delete_assessment(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        a = create_assessment(client, w["id"])
        r = client.delete(f"/assessments/{a['id']}")
        assert r.status_code == 204
        assert client.get(f"/assessments/{a['id']}").status_code == 404


# ═══════════════════════════════════════════════════════════════════════════
# Reports
# ═══════════════════════════════════════════════════════════════════════════

class TestReports:
    def test_wound_progress_report(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        create_assessment(client, w["id"])
        # Second assessment with larger area (deteriorating)
        payload2 = {
            **ASSESSMENT_PAYLOAD_BASE,
            "wound_id": w["id"],
            "area_cm2": 10.0,
            "healing_status": "deteriorating",
        }
        client.post("/assessments/", json=payload2)

        r = client.get(f"/reports/wound-progress/{w['id']}")
        assert r.status_code == 200
        data = r.json()
        assert data["total_assessments"] == 2
        assert data["initial_area_cm2"] == 7.0
        assert data["latest_area_cm2"] == 10.0
        assert data["area_change_pct"] == pytest.approx(42.86, abs=0.01)
        assert data["latest_healing_status"] == "deteriorating"

    def test_wound_progress_no_assessments(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        r = client.get(f"/reports/wound-progress/{w['id']}")
        assert r.status_code == 200
        data = r.json()
        assert data["total_assessments"] == 0
        assert data["latest_area_cm2"] is None
        assert data["area_change_pct"] is None

    def test_patient_summary(self, client):
        p = create_patient(client)
        w = create_wound(client, p["id"])
        create_assessment(client, w["id"])
        r = client.get(f"/reports/patient-summary/{p['id']}")
        assert r.status_code == 200
        data = r.json()
        assert data["wound_count"] == 1
        assert data["wounds"][0]["wound_id"] == w["id"]

    def test_patient_summary_no_wounds(self, client):
        p = create_patient(client)
        r = client.get(f"/reports/patient-summary/{p['id']}")
        assert r.status_code == 404

    def test_wound_progress_not_found(self, client):
        r = client.get("/reports/wound-progress/9999")
        assert r.status_code == 404
