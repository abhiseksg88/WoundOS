"""
CarePlix WoundOS – Wound Care Management System
"""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.database import Base, engine
from app.routers import assessments, patients, reports, wounds

# Ensure the database tables exist
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="CarePlix WoundOS",
    description=(
        "AI-powered wound care management system. "
        "Tracks patients, wounds, assessments, and healing progress "
        "with optional CarePlix scan integration."
    ),
    version="1.0.0",
    contact={
        "name": "CarePlix WoundOS",
        "url": "https://careplix.com",
    },
    license_info={"name": "Proprietary"},
)

# Allow the frontend (served separately during development) to call the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["System"])
def health_check():
    return {"status": "ok", "system": "CarePlix WoundOS"}


# Register routers
app.include_router(patients.router)
app.include_router(wounds.router)
app.include_router(assessments.router)
app.include_router(reports.router)

# Serve the static frontend – must be mounted LAST so that API routes take
# precedence over the catch-all StaticFiles handler.
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="frontend")
