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

from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.config import get_settings, Settings
from app.database import get_db, init_db
from app.logging_config import setup_logging
from app import crud, models, schemas
from app.rate_limit import (
    limiter,
    device_limiter_body,
    device_limiter_query,
    PAIR_RATE_LIMIT,
    UPDATE_LOCATION_DEVICE_LIMIT,
    UPDATE_LOCATION_IP_LIMIT,
    PARTNER_LOCATION_DEVICE_LIMIT,
    PARTNER_LOCATION_IP_LIMIT,
    log_rate_limit_exceeded,
)

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
    version="0.4.0",  # Updated version for Phase 4 (Rate Limiting & Security)
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

# Register rate limiter with FastAPI
app.state.limiter = limiter

# Add SlowAPI middleware
from slowapi.middleware import SlowAPIASGIMiddleware
app.add_middleware(SlowAPIASGIMiddleware)


# ============================================================================
# Security Headers Middleware
# ============================================================================

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """
    Add security headers to all responses.

    Security headers protect against common web vulnerabilities:
    - X-Content-Type-Options: Prevents MIME sniffing attacks
    - X-Frame-Options: Prevents clickjacking attacks
    - X-XSS-Protection: Enables browser XSS filtering
    - Strict-Transport-Security: Enforces HTTPS in production
    """
    response = await call_next(request)

    # Prevent MIME sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"

    # Prevent clickjacking
    response.headers["X-Frame-Options"] = "DENY"

    # Enable XSS filter (legacy browsers)
    response.headers["X-XSS-Protection"] = "1; mode=block"

    # Enforce HTTPS in production
    if settings.is_production:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response


# Rate limit exception handler
@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    """
    Handle rate limit exceeded errors.

    Returns a 429 Too Many Requests response when a client exceeds
    the configured rate limits.

    Args:
        request: FastAPI request object
        exc: Rate limit exception

    Returns:
        JSONResponse: 429 error with retry information
    """
    # Log rate limit event (privacy-conscious: only IP, not request body)
    log_rate_limit_exceeded(request, request.url.path)

    return JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content={"detail": "Rate limit exceeded. Please try again later."}
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
        "version": "0.3.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "pair": "POST /pair",
            "updateLocation": "POST /updateLocation",
            "partnerLocation": "GET /partnerLocation"
        },
        "rate_limiting": {
            "pair": "5 requests/minute per IP",
            "updateLocation": "6 requests/minute per device, 60/minute per IP",
            "partnerLocation": "12 requests/minute per device, 120/minute per IP"
        }
    }


# ============================================================================
# Pairing Routes
# ============================================================================

@app.post("/pair", responses={200: {"model": schemas.PairingResponse}})
@limiter.limit(PAIR_RATE_LIMIT)
def pair(
    request: Request,
    payload: schemas.PairingRequest,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    Create or join a couple via pairing code.

    This endpoint supports two actions:
    1. "create": Generate a new couple_id (pairing code) for the creator
    2. "join": Join an existing couple using a pairing code

    Create Action:
        - Generates a unique 8-character alphanumeric pairing code
        - No location is stored yet (that happens on first /updateLocation call)
        - Returns the generated couple_id with role="creator"

    Join Action:
        - Validates the pairing code exists
        - Enforces 2-device limit per couple
        - Returns couple_id with role="partner" and count of existing devices

    Args:
        payload: Pairing request with action, device_id, and optionally couple_id
        db: Database session (injected via dependency)

    Returns:
        PairingResponse: Pairing details with couple_id, device_id, and role

    Raises:
        HTTPException: 400 if validation fails, 404 if pairing code not found,
                      409 if couple already has 2 devices, 500 for database errors
    """
    try:
        # ====================================================================
        # CREATE ACTION: Generate a new pairing code
        # ====================================================================
        if payload.action == "create":
            # Generate unique couple_id
            couple_id = crud.generate_unique_couple_id(db)

            logger.info(
                f"Pairing code created: couple_id={couple_id}, device_id={payload.device_id}"
            )

            response_data = schemas.PairingResponse(
                couple_id=couple_id,
                device_id=payload.device_id,
                role="creator",
                existing_devices=None,
            )
            return JSONResponse(content=response_data.model_dump(mode='json'))

        # ====================================================================
        # JOIN ACTION: Join an existing couple
        # ====================================================================
        elif payload.action == "join":
            # Validate couple_id is provided
            if not payload.couple_id:
                logger.warning(
                    f"Join attempt without couple_id from device_id={payload.device_id}"
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="couple_id is required for 'join' action"
                )

            # Check how many devices are already paired
            device_count = crud.count_devices_for_couple(db, payload.couple_id)

            # Case 1: Pairing code doesn't exist (no devices)
            if device_count == 0:
                logger.info(
                    f"Join attempt with non-existent couple_id={payload.couple_id}"
                )
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Pairing code not found"
                )

            # Case 2: Couple already has 2 devices (limit reached)
            if device_count >= 2:
                logger.warning(
                    f"Join attempt rejected: couple_id={payload.couple_id} already has {device_count} devices"
                )
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This couple is already paired with 2 devices"
                )

            # Case 3: 1 device exists, allow join
            logger.info(
                f"Device joined couple: couple_id={payload.couple_id}, "
                f"device_id={payload.device_id}, existing_devices={device_count}"
            )

            response_data = schemas.PairingResponse(
                couple_id=payload.couple_id,
                device_id=payload.device_id,
                role="partner",
                existing_devices=device_count,
            )
            return JSONResponse(content=response_data.model_dump(mode='json'))

        # ====================================================================
        # INVALID ACTION
        # ====================================================================
        else:
            logger.warning(
                f"Invalid pairing action: {payload.action} from device_id={payload.device_id}"
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid action: {payload.action}. Must be 'create' or 'join'"
            )

    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during pairing for device_id={payload.device_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process pairing request due to database error"
        )

    except Exception as e:
        logger.error(
            f"Unexpected error during pairing for device_id={payload.device_id}: {str(e)}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred"
        )


# ============================================================================
# Location Routes
# ============================================================================

@app.post("/updateLocation", responses={200: {"model": schemas.LocationUpdateResponse}})
@device_limiter_body.limit(UPDATE_LOCATION_DEVICE_LIMIT)
@limiter.limit(UPDATE_LOCATION_IP_LIMIT)
def update_location(
    request: Request,
    payload: schemas.LocationUpdateRequest,
    db: Session = Depends(get_db),
) -> JSONResponse:
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

        response_data = schemas.LocationUpdateResponse(
            success=True,
            updated_at=device.updated_at,
        )
        return JSONResponse(content=response_data.model_dump(mode='json'))

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


@app.get("/partnerLocation", responses={200: {"model": schemas.PartnerLocationResponse}})
@device_limiter_query.limit(PARTNER_LOCATION_DEVICE_LIMIT)
@limiter.limit(PARTNER_LOCATION_IP_LIMIT)
def partner_location(
    request: Request,
    couple_id: str,
    device_id: str,
    db: Session = Depends(get_db),
) -> JSONResponse:
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
            response_data = schemas.PartnerLocationResponse(partner_found=False)
            return JSONResponse(content=response_data.model_dump(mode='json'))

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
            response_data = schemas.PartnerLocationResponse(
                partner_found=True,
                is_sharing=False,
                staleness_seconds=staleness_seconds,
            )
            return JSONResponse(content=response_data.model_dump(mode='json'))

        # Case 3: Partner sharing location
        logger.debug(
            f"Partner location retrieved for couple_id={couple_id}, device_id={device_id}"
        )
        response_data = schemas.PartnerLocationResponse(
            partner_found=True,
            is_sharing=True,
            latitude=partner.latitude,
            longitude=partner.longitude,
            updated_at=partner_updated_at,
            staleness_seconds=staleness_seconds,
        )
        return JSONResponse(content=response_data.model_dump(mode='json'))

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
# Deployment configuration (Phase 5)
