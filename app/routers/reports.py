from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.models import Assessment, Wound
from app.schemas.schemas import WoundProgressReport

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.get("/wound-progress/{wound_id}", response_model=WoundProgressReport)
def wound_progress_report(wound_id: int, db: Session = Depends(get_db)):
    """
    Generate a healing progress report for a specific wound.

    Compares the first and latest assessments to calculate area change
    and determines the overall healing trajectory.
    """
    wound = db.query(Wound).filter(Wound.id == wound_id).first()
    if not wound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Wound not found")

    assessments = (
        db.query(Assessment)
        .filter(Assessment.wound_id == wound_id)
        .order_by(Assessment.assessment_date.asc())
        .all()
    )

    initial_area = assessments[0].area_cm2 if assessments else None
    latest_area = assessments[-1].area_cm2 if assessments else None
    latest_healing_status = assessments[-1].healing_status if assessments else None

    area_change_pct = None
    if initial_area and latest_area and initial_area > 0:
        area_change_pct = round(((latest_area - initial_area) / initial_area) * 100, 2)

    return WoundProgressReport(
        wound_id=wound.id,
        patient_id=wound.patient_id,
        wound_type=wound.wound_type,
        location=wound.location,
        total_assessments=len(assessments),
        initial_area_cm2=initial_area,
        latest_area_cm2=latest_area,
        area_change_pct=area_change_pct,
        latest_healing_status=latest_healing_status,
        assessments=assessments,
    )


@router.get("/patient-summary/{patient_id}")
def patient_summary(patient_id: int, db: Session = Depends(get_db)):
    """
    Return a summary of all wounds and their latest assessments for a patient.
    """
    wounds = db.query(Wound).filter(Wound.patient_id == patient_id).all()
    if not wounds:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No wounds found for this patient",
        )

    summary = []
    for wound in wounds:
        latest_assessment = (
            db.query(Assessment)
            .filter(Assessment.wound_id == wound.id)
            .order_by(Assessment.assessment_date.desc())
            .first()
        )
        summary.append(
            {
                "wound_id": wound.id,
                "wound_type": wound.wound_type,
                "location": wound.location,
                "stage": wound.stage,
                "created_at": wound.created_at,
                "latest_assessment_date": (
                    latest_assessment.assessment_date if latest_assessment else None
                ),
                "latest_healing_status": (
                    latest_assessment.healing_status if latest_assessment else None
                ),
                "latest_area_cm2": (
                    latest_assessment.area_cm2 if latest_assessment else None
                ),
            }
        )

    return {"patient_id": patient_id, "wound_count": len(wounds), "wounds": summary}
