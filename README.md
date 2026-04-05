# WoundOS
CarePlix WoundOS

---

## CarePlix WoundOS – AI-Powered Wound Care Management System

CarePlix WoundOS is a wound care management platform that helps clinicians track patients, document wound assessments, monitor healing progress, and optionally integrate with CarePlix scanning technology for advanced AI-powered analysis.

### Features

- **Patient Management** – Register and manage patient demographics, medical history, and allergies
- **Wound Tracking** – Record wounds with type, location, staging, and descriptions
- **Assessment Documentation** – Capture detailed wound measurements, characteristics, healing status, and wound images
- **Progress Reports** – Generate per-wound healing progress reports and patient-level summaries
- **CarePlix Scan Integration** – Store raw scan data (PPG time series, average FPS) from CarePlix scanning SDK
- **REST API** – Full OpenAPI 3.1 documented API with interactive Swagger UI at `/docs`
- **Web Frontend** – Responsive single-page interface for clinical workflows

---

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Python 3.12, FastAPI |
| Database | SQLite via SQLAlchemy |
| Frontend | HTML5 / CSS3 / Vanilla JS |
| Testing | pytest + HTTPX |

---

### Quick Start

#### 1. Install dependencies

```bash
pip install -r requirements.txt
```

#### 2. Start the server

```bash
uvicorn app.main:app --reload
```

The server starts on **http://localhost:8000** by default.

- **Web UI**: http://localhost:8000
- **Swagger / Interactive API Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

---

### API Overview

| Resource | Endpoint | Methods |
|----------|----------|---------|
| Health | `/health` | GET |
| Patients | `/patients/` | GET, POST |
| Patient | `/patients/{id}` | GET, PUT, DELETE |
| Wounds | `/wounds/` | GET, POST |
| Wound | `/wounds/{id}` | GET, PUT, DELETE |
| Assessments | `/assessments/` | GET, POST |
| Assessment with image | `/assessments/with-image` | POST (multipart) |
| Assessment | `/assessments/{id}` | GET, DELETE |
| Wound Progress Report | `/reports/wound-progress/{wound_id}` | GET |
| Patient Summary | `/reports/patient-summary/{patient_id}` | GET |

#### Example: Register a patient

```bash
curl -X POST http://localhost:8000/patients/ \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Jane",
    "last_name": "Doe",
    "date_of_birth": "1985-06-15",
    "gender": "female",
    "mrn": "MRN-0001"
  }'
```

#### Example: Record a wound assessment with an image

```bash
curl -X POST http://localhost:8000/assessments/with-image \
  -F "wound_id=1" \
  -F "assessed_by=Dr. Smith" \
  -F "length_cm=3.5" \
  -F "width_cm=2.0" \
  -F "area_cm2=7.0" \
  -F "healing_status=improving" \
  -F "pain_score=4" \
  -F "image=@/path/to/wound_photo.jpg"
```

---

### CarePlix Scan Integration

Assessments accept scan data from the [CarePlix Scan SDK](https://github.com/CareNow-HealthCare/careplix-scan-sdk):

```javascript
import { facescan } from "careplix-scan-sdk";

facescan.onScanFinish(async ({ raw_intensity, ppg_time, average_fps }) => {
  await fetch("/assessments/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      wound_id: selectedWoundId,
      assessed_by: clinicianName,
      scan_raw_intensity: JSON.stringify(raw_intensity),
      scan_ppg_time: JSON.stringify(ppg_time),
      scan_average_fps: average_fps,
    }),
  });
});
```

---

### Running Tests

```bash
pytest tests/ -v
```

All 27 tests cover:
- Patient CRUD (create, read, update, delete, duplicate MRN)
- Wound CRUD and cascade deletion
- Assessment CRUD and validation (pain score range, invalid wound)
- Progress reports and patient summaries

---

### Project Structure

```
WoundOS/
├── app/
│   ├── main.py              # FastAPI application entry point
│   ├── database.py          # SQLAlchemy engine and session
│   ├── models/
│   │   └── models.py        # ORM models (Patient, Wound, Assessment)
│   ├── schemas/
│   │   └── schemas.py       # Pydantic request/response schemas
│   ├── routers/
│   │   ├── patients.py      # Patient CRUD endpoints
│   │   ├── wounds.py        # Wound CRUD endpoints
│   │   ├── assessments.py   # Assessment endpoints + image upload
│   │   └── reports.py       # Progress and summary reports
│   └── services/
├── frontend/
│   ├── index.html           # Single-page web interface
│   ├── css/styles.css
│   └── js/
│       ├── api.js           # API client wrapper
│       └── app.js           # Application logic
├── tests/
│   └── test_api.py          # pytest test suite (27 tests)
├── uploads/                 # Wound image storage
├── requirements.txt
└── pyproject.toml
```
