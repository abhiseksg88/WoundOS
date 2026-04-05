from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.models import Patient, Wound
from app.schemas.schemas import WoundCreate, WoundDetail, WoundResponse, WoundUpdate

router = APIRouter(prefix="/wounds", tags=["Wounds"])


@router.get("/", response_model=List[WoundResponse])
def list_wounds(
    patient_id: int = None, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
):
    """List all wounds, optionally filtered by patient."""
    query = db.query(Wound)
    if patient_id is not None:
        query = query.filter(Wound.patient_id == patient_id)
    return query.offset(skip).limit(limit).all()


@router.post("/", response_model=WoundResponse, status_code=status.HTTP_201_CREATED)
def create_wound(wound: WoundCreate, db: Session = Depends(get_db)):
    """Record a new wound for a patient."""
    patient = db.query(Patient).filter(Patient.id == wound.patient_id).first()
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Patient with id {wound.patient_id} not found.",
        )
    db_wound = Wound(**wound.model_dump())
    db.add(db_wound)
    db.commit()
    db.refresh(db_wound)
    return db_wound


@router.get("/{wound_id}", response_model=WoundDetail)
def get_wound(wound_id: int, db: Session = Depends(get_db)):
    """Get a wound with all its assessments."""
    wound = db.query(Wound).filter(Wound.id == wound_id).first()
    if not wound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wound not found")
    return wound


@router.put("/{wound_id}", response_model=WoundResponse)
def update_wound(wound_id: int, updates: WoundUpdate, db: Session = Depends(get_db)):
    """Update wound details."""
    wound = db.query(Wound).filter(Wound.id == wound_id).first()
    if not wound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wound not found")
    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(wound, field, value)
    db.commit()
    db.refresh(wound)
    return wound


@router.delete("/{wound_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wound(wound_id: int, db: Session = Depends(get_db)):
    """Delete a wound and all its assessments."""
    wound = db.query(Wound).filter(Wound.id == wound_id).first()
    if not wound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wound not found")
    db.delete(wound)
    db.commit()
