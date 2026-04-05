from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, field_validator

from app.models.models import Gender, HealingStatus, WoundStage, WoundType


# ---------------------------------------------------------------------------
# Patient Schemas
# ---------------------------------------------------------------------------


class PatientBase(BaseModel):
    first_name: str
    last_name: str
    date_of_birth: str
    gender: Gender
    mrn: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    medical_history: Optional[str] = None
    allergies: Optional[str] = None


class PatientCreate(PatientBase):
    pass


class PatientUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[Gender] = None
    mrn: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    medical_history: Optional[str] = None
    allergies: Optional[str] = None


class PatientResponse(PatientBase):
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PatientDetail(PatientResponse):
    wounds: List["WoundResponse"] = []

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Wound Schemas
# ---------------------------------------------------------------------------


class WoundBase(BaseModel):
    wound_type: WoundType
    location: str
    stage: Optional[WoundStage] = None
    description: Optional[str] = None


class WoundCreate(WoundBase):
    patient_id: int


class WoundUpdate(BaseModel):
    wound_type: Optional[WoundType] = None
    location: Optional[str] = None
    stage: Optional[WoundStage] = None
    description: Optional[str] = None


class WoundResponse(WoundBase):
    id: int
    patient_id: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class WoundDetail(WoundResponse):
    assessments: List["AssessmentResponse"] = []

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Assessment Schemas
# ---------------------------------------------------------------------------


class AssessmentBase(BaseModel):
    assessed_by: str
    length_cm: Optional[float] = None
    width_cm: Optional[float] = None
    depth_cm: Optional[float] = None
    area_cm2: Optional[float] = None
    wound_bed: Optional[str] = None
    exudate_amount: Optional[str] = None
    exudate_type: Optional[str] = None
    wound_edges: Optional[str] = None
    periwound_skin: Optional[str] = None
    odor: Optional[str] = None
    pain_score: Optional[int] = None
    healing_status: Optional[HealingStatus] = None
    notes: Optional[str] = None
    treatment_plan: Optional[str] = None
    scan_raw_intensity: Optional[str] = None
    scan_ppg_time: Optional[str] = None
    scan_average_fps: Optional[float] = None

    @field_validator("pain_score")
    @classmethod
    def pain_score_range(cls, v):
        if v is not None and not (0 <= v <= 10):
            raise ValueError("pain_score must be between 0 and 10")
        return v


class AssessmentCreate(AssessmentBase):
    wound_id: int


class AssessmentResponse(AssessmentBase):
    id: int
    wound_id: int
    assessment_date: datetime
    image_filename: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Report Schemas
# ---------------------------------------------------------------------------


class WoundProgressReport(BaseModel):
    wound_id: int
    patient_id: int
    wound_type: WoundType
    location: str
    total_assessments: int
    latest_area_cm2: Optional[float]
    initial_area_cm2: Optional[float]
    area_change_pct: Optional[float]
    latest_healing_status: Optional[HealingStatus]
    assessments: List[AssessmentResponse]

    model_config = {"from_attributes": True}


# Resolve forward references
PatientDetail.model_rebuild()
WoundDetail.model_rebuild()
