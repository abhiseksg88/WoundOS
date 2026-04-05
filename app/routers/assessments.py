import os
import uuid
from pathlib import Path
from typing import List, Optional

import aiofiles
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.models import Assessment, Wound
from app.schemas.schemas import AssessmentCreate, AssessmentResponse

router = APIRouter(prefix="/assessments", tags=["Assessments"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.get("/", response_model=List[AssessmentResponse])
def list_assessments(
    wound_id: int = None, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
):
    """List assessments, optionally filtered by wound."""
    query = db.query(Assessment)
    if wound_id is not None:
        query = query.filter(Assessment.wound_id == wound_id)
    return query.order_by(Assessment.assessment_date.desc()).offset(skip).limit(limit).all()


@router.post("/", response_model=AssessmentResponse, status_code=status.HTTP_201_CREATED)
def create_assessment(assessment: AssessmentCreate, db: Session = Depends(get_db)):
    """Create a new wound assessment."""
    wound = db.query(Wound).filter(Wound.id == assessment.wound_id).first()
    if not wound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Wound with id {assessment.wound_id} not found.",
        )
    db_assessment = Assessment(**assessment.model_dump())
    db.add(db_assessment)
    db.commit()
    db.refresh(db_assessment)
    return db_assessment


@router.post(
    "/with-image",
    response_model=AssessmentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_assessment_with_image(
    wound_id: int = Form(...),
    assessed_by: str = Form(...),
    length_cm: Optional[float] = Form(None),
    width_cm: Optional[float] = Form(None),
    depth_cm: Optional[float] = Form(None),
    area_cm2: Optional[float] = Form(None),
    wound_bed: Optional[str] = Form(None),
    exudate_amount: Optional[str] = Form(None),
    exudate_type: Optional[str] = Form(None),
    wound_edges: Optional[str] = Form(None),
    periwound_skin: Optional[str] = Form(None),
    odor: Optional[str] = Form(None),
    pain_score: Optional[int] = Form(None),
    healing_status: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    treatment_plan: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    """Create an assessment with an optional wound image upload."""
    wound = db.query(Wound).filter(Wound.id == wound_id).first()
    if not wound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Wound with id {wound_id} not found.",
        )

    image_filename = None
    if image and image.filename:
        if image.content_type not in ALLOWED_IMAGE_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported image type '{image.content_type}'. Allowed: JPEG, PNG, WEBP.",
            )
        ext = Path(image.filename).suffix
        image_filename = f"{uuid.uuid4().hex}{ext}"
        dest = UPLOAD_DIR / image_filename
        async with aiofiles.open(dest, "wb") as out_file:
            content = await image.read()
            await out_file.write(content)

    if pain_score is not None and not (0 <= pain_score <= 10):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="pain_score must be between 0 and 10",
        )

    db_assessment = Assessment(
        wound_id=wound_id,
        assessed_by=assessed_by,
        length_cm=length_cm,
        width_cm=width_cm,
        depth_cm=depth_cm,
        area_cm2=area_cm2,
        wound_bed=wound_bed,
        exudate_amount=exudate_amount,
        exudate_type=exudate_type,
        wound_edges=wound_edges,
        periwound_skin=periwound_skin,
        odor=odor,
        pain_score=pain_score,
        healing_status=healing_status,
        notes=notes,
        treatment_plan=treatment_plan,
        image_filename=image_filename,
    )
    db.add(db_assessment)
    db.commit()
    db.refresh(db_assessment)
    return db_assessment


@router.get("/{assessment_id}", response_model=AssessmentResponse)
def get_assessment(assessment_id: int, db: Session = Depends(get_db)):
    """Retrieve a specific assessment."""
    assessment = db.query(Assessment).filter(Assessment.id == assessment_id).first()
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assessment not found"
        )
    return assessment


@router.delete("/{assessment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_assessment(assessment_id: int, db: Session = Depends(get_db)):
    """Delete an assessment and its associated image."""
    assessment = db.query(Assessment).filter(Assessment.id == assessment_id).first()
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Assessment not found"
        )
    if assessment.image_filename:
        img_path = UPLOAD_DIR / assessment.image_filename
        if img_path.exists():
            img_path.unlink()
    db.delete(assessment)
    db.commit()
