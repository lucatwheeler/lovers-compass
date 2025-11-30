"""
Lover's Compass - FastAPI Application

Main application entry point with FastAPI configuration, middleware,
and route definitions.

Features:
- Health check endpoint
- Location update endpoint (POST /updateLocation)
- Partner location retrieval (GET /partnerLocation)
- CORS middleware for iOS app
- Database initialization on startup
- Centralized logging configuration
"""

import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import AsyncGenerator

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.config import get_settings, Settings
from app.database import get_db, init_db
from app.logging_config import setup_logging
from app import crud, models, schemas

# Initialize logging first
setup_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    Application lifespan context manager.

    Handles startup and shutdown events for the FastAPI application.

    Startup:
        - Logs application start
        - Initializes database (creates tables if they don't exist)

    Shutdown:
        - Logs application shutdown
        - Cleanup operations (if needed in future)
    """
    # Startup
    settings = get_settings()
    logger.info(f"Starting Lover's Compass API - Environment: {settings.ENV}")
    logger.info(f"Database: {settings.DATABASE_URL}")

    # Initialize database tables
    try:
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise

    yield

    # Shutdown
    logger.info("Shutting down Lover's Compass API")


# Create FastAPI application
app = FastAPI(
    title="Lover's Compass API",
    description="A minimal, private location-sharing API for couples",
    version="0.2.0",  # Updated version for Phase 2
    lifespan=lifespan,
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc",  # ReDoc
)

# Get settings for CORS configuration
settings = get_settings()

# Configure CORS middleware
# Allows iOS app to make API requests from different origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods (GET, POST, etc.)
    allow_headers=["*"],  # Allow all headers
)


# ============================================================================
# Health & Info Routes
# ============================================================================

@app.get("/health")
async def health_check():
    """
    Health check endpoint.

    Returns a simple status response to verify the API is running.
    Used for monitoring, load balancer health checks, and deployment verification.

    Returns:
        dict: Status indicator
    """
    return {"status": "ok"}


@app.get("/")
async def root():
    """
    Root endpoint with API information.

    Provides basic information about the API and links to documentation.

    Returns:
        dict: API metadata
    """
    return {
        "name": "Lover's Compass API",
        "version": "0.2.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "updateLocation": "POST /updateLocation",
            "partnerLocation": "GET /partnerLocation"
        }
    }


# ============================================================================
# Location Routes
# ============================================================================

@app.post("/updateLocation", response_model=schemas.LocationUpdateResponse)
def update_location(
    payload: schemas.LocationUpdateRequest,
    db: Session = Depends(get_db),
):
    """
    Update or create a device's location.

    This endpoint implements an "upsert" pattern: if a location record
    already exists for the given couple_id:device_id combination, it
    updates the existing record. Otherwise, it creates a new record.

    Privacy Note: Only the most recent location is stored per device.
    No historical location data is retained.

    Args:
        payload: Location update request with couple_id, device_id, coordinates, and sharing status
        db: Database session (injected via dependency)

    Returns:
        LocationUpdateResponse: Success status and timestamp of update

    Raises:
        HTTPException: 500 if database operation fails
    """
    try:
        # Upsert the device location
        device = crud.upsert_device_location(db, payload)

        logger.info(
            f"Location updated successfully for couple_id={payload.couple_id}, "
            f"device_id={payload.device_id}"
        )

        return schemas.LocationUpdateResponse(
            success=True,
            updated_at=device.updated_at,
        )

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during location update for couple_id={payload.couple_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=500,
            detail="Failed to update location due to database error"
        )
    except Exception as e:
        logger.error(
            f"Unexpected error during location update for couple_id={payload.couple_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred"
        )


@app.get("/partnerLocation", response_model=schemas.PartnerLocationResponse)
def partner_location(
    couple_id: str,
    device_id: str,
    db: Session = Depends(get_db),
):
    """
    Retrieve the partner's latest location.

    This endpoint returns the location of the OTHER device in the couple
    (i.e., not the caller's device).

    Three scenarios are handled:
    1. No partner exists yet (partner_found=False)
    2. Partner exists but not sharing location (is_sharing=False, no coordinates)
    3. Partner exists and sharing (is_sharing=True, with coordinates and staleness)

    Privacy Note: Coordinates are only returned if the partner is actively sharing.

    Args:
        couple_id: Unique identifier for the couple
        device_id: Device ID of the requester (to exclude from results)
        db: Database session (injected via dependency)

    Returns:
        PartnerLocationResponse: Partner's location status and coordinates (if sharing)

    Raises:
        HTTPException: 500 if database operation fails
    """
    try:
        # Retrieve partner's location
        partner = crud.get_partner_location(db, couple_id, device_id)

        # Case 1: No partner found
        if partner is None:
            logger.debug(
                f"No partner found for couple_id={couple_id}, device_id={device_id}"
            )
            return schemas.PartnerLocationResponse(partner_found=False)

        # Calculate staleness (time since last update)
        now = datetime.now(timezone.utc)

        # Handle timezone-aware vs naive datetime
        if partner.updated_at.tzinfo is None:
            # If stored datetime is naive, assume UTC
            partner_updated_at = partner.updated_at.replace(tzinfo=timezone.utc)
        else:
            partner_updated_at = partner.updated_at

        staleness_seconds = int((now - partner_updated_at).total_seconds())

        # Case 2: Partner not sharing location
        if not partner.is_sharing:
            logger.debug(
                f"Partner not sharing for couple_id={couple_id}, device_id={device_id}"
            )
            return schemas.PartnerLocationResponse(
                partner_found=True,
                is_sharing=False,
                staleness_seconds=staleness_seconds,
            )

        # Case 3: Partner sharing location
        logger.debug(
            f"Partner location retrieved for couple_id={couple_id}, device_id={device_id}"
        )
        return schemas.PartnerLocationResponse(
            partner_found=True,
            is_sharing=True,
            latitude=partner.latitude,
            longitude=partner.longitude,
            updated_at=partner_updated_at,
            staleness_seconds=staleness_seconds,
        )

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during partner location retrieval for couple_id={couple_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve partner location due to database error"
        )
    except Exception as e:
        logger.error(
            f"Unexpected error during partner location retrieval for couple_id={couple_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred"
        )


# ============================================================================
# Future Endpoints (To be implemented in later phases)
# ============================================================================
# POST /pair - Generate or validate pairing codes (Phase 3)
# Rate limiting middleware (Phase 4)
# Deployment configuration (Phase 5)
