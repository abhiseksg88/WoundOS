import enum
from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from app.database import Base


class Gender(str, enum.Enum):
    male = "male"
    female = "female"
    other = "other"


class WoundType(str, enum.Enum):
    pressure_ulcer = "pressure_ulcer"
    diabetic_foot = "diabetic_foot"
    venous_leg = "venous_leg"
    arterial = "arterial"
    surgical = "surgical"
    traumatic = "traumatic"
    burn = "burn"
    other = "other"


class WoundStage(str, enum.Enum):
    stage_1 = "stage_1"
    stage_2 = "stage_2"
    stage_3 = "stage_3"
    stage_4 = "stage_4"
    unstageable = "unstageable"
    deep_tissue = "deep_tissue"


class HealingStatus(str, enum.Enum):
    improving = "improving"
    stable = "stable"
    deteriorating = "deteriorating"
    healed = "healed"


class Patient(Base):
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    date_of_birth = Column(String(20), nullable=False)
    gender = Column(Enum(Gender), nullable=False)
    mrn = Column(String(50), unique=True, index=True)
    phone = Column(String(20))
    email = Column(String(100))
    address = Column(Text)
    medical_history = Column(Text)
    allergies = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    wounds = relationship("Wound", back_populates="patient", cascade="all, delete-orphan")


class Wound(Base):
    __tablename__ = "wounds"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    wound_type = Column(Enum(WoundType), nullable=False)
    location = Column(String(200), nullable=False)
    stage = Column(Enum(WoundStage))
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    patient = relationship("Patient", back_populates="wounds")
    assessments = relationship(
        "Assessment", back_populates="wound", cascade="all, delete-orphan"
    )


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(Integer, primary_key=True, index=True)
    wound_id = Column(Integer, ForeignKey("wounds.id"), nullable=False)
    assessed_by = Column(String(200), nullable=False)
    assessment_date = Column(DateTime, default=datetime.utcnow)

    # Wound measurements
    length_cm = Column(Float)
    width_cm = Column(Float)
    depth_cm = Column(Float)
    area_cm2 = Column(Float)

    # Wound characteristics
    wound_bed = Column(String(200))
    exudate_amount = Column(String(50))
    exudate_type = Column(String(100))
    wound_edges = Column(String(200))
    periwound_skin = Column(String(200))
    odor = Column(String(100))
    pain_score = Column(Integer)

    # Healing status
    healing_status = Column(Enum(HealingStatus))
    notes = Column(Text)
    treatment_plan = Column(Text)

    # Image reference
    image_filename = Column(String(255))

    # CarePlix scan data
    scan_raw_intensity = Column(Text)
    scan_ppg_time = Column(Text)
    scan_average_fps = Column(Float)

    created_at = Column(DateTime, default=datetime.utcnow)

    wound = relationship("Wound", back_populates="assessments")
