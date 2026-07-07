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

from fastapi import FastAPI, Depends, HTTPException, status, Request, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
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
    device_limiter_query,
    PAIR_RATE_LIMIT,
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

    # Prune couples abandoned for 30+ days (best-effort)
    try:
        from app.database import SessionLocal
        db = SessionLocal()
        try:
            crud.prune_stale_couples(db)
        finally:
            db.close()
    except Exception as e:
        logger.warning(f"Stale couple pruning failed (non-fatal): {e}")

    yield

    # Shutdown
    logger.info("Shutting down Lover's Compass API")


# Get settings first (needed for conditional app config)
settings = get_settings()

# Create FastAPI application
app = FastAPI(
    title="Lover's Compass API",
    description="A minimal, private location-sharing API for couples",
    version="1.0.0",  # Device token auth, poke messages, invite links
    lifespan=lifespan,
    # Hide interactive docs in production; the API surface is small and
    # the docs advertise endpoints to strangers.
    docs_url=None if settings.is_production else "/docs",
    redoc_url=None if settings.is_production else "/redoc",
)

# Configure CORS middleware.
# The native apps don't need CORS and the PWA is served same-origin;
# this exists only for local development against a separate frontend port.
# allow_credentials must be False when origins is "*" (the browser rejects
# the combination anyway), and we never use cookies.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=False,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
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

    # Prevent clickjacking (allow embedding from Command Center)
    response.headers["X-Frame-Options"] = "SAMEORIGIN"

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
# Device Authentication
# ============================================================================

def _extract_bearer_token(request: Request) -> str | None:
    """Pull the bearer token from the Authorization header, if present."""
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[len("Bearer "):].strip()
        return token or None
    return None


def authenticate_device(
    db: Session,
    request: Request,
    couple_id: str,
    device_id: str,
) -> models.DeviceLocation:
    """
    Verify that the caller is the registered device it claims to be.

    - 404 if the couple/device combination doesn't exist.
    - 401 if the device has a token on file and the caller's bearer token
      doesn't match.
    - Devices paired before token auth (token_hash is NULL) are allowed
      through; they can claim a token via POST /auth/token, after which
      the token is required.

    Returns the device's DeviceLocation record.
    """
    record = db.query(models.DeviceLocation).filter(
        models.DeviceLocation.id == f"{couple_id}:{device_id}"
    ).first()

    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Couple not found or device not registered",
        )

    if record.token_hash:
        token = _extract_bearer_token(request)
        if not token or not crud.verify_token(token, record.token_hash):
            logger.warning(
                f"Auth failure for couple_id={couple_id}, device_id={device_id}"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing device token",
            )

    return record


@app.post("/auth/token", responses={200: {"model": schemas.TokenResponse}})
@limiter.limit("5/minute")
def claim_token(
    request: Request,
    payload: schemas.TokenRequest,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    One-time token claim for devices paired before token auth existed.

    Succeeds only while the device record has no token on file. Once a
    token is claimed (or was issued at pairing time), this returns 409.
    """
    record = db.query(models.DeviceLocation).filter(
        models.DeviceLocation.id == f"{payload.couple_id}:{payload.device_id}"
    ).first()

    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Couple not found or device not registered",
        )

    if record.token_hash:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This device already has a token",
        )

    token = crud.generate_auth_token()
    record.token_hash = crud.hash_token(token)
    db.commit()
    logger.info(
        f"Legacy device claimed token: couple_id={payload.couple_id}, "
        f"device_id={payload.device_id}"
    )
    return JSONResponse(content={"auth_token": token})


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


@app.get("/api")
async def api_info():
    """API information endpoint."""
    return {
        "name": "Lover's Compass API",
        "version": app.version,
        "status": "running",
        "health": "/health",
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

            # Mint a device token; only its hash is stored
            auth_token = crud.generate_auth_token()

            # Store creator device record so join can find this couple_id
            from app.models import DeviceLocation
            from datetime import datetime, timezone as tz
            creator_record = DeviceLocation(
                id=f"{couple_id}:{payload.device_id}",
                couple_id=couple_id,
                device_id=payload.device_id,
                latitude=None,
                longitude=None,
                updated_at=datetime.now(tz.utc),
                is_sharing=False,
                token_hash=crud.hash_token(auth_token),
            )
            db.add(creator_record)
            db.commit()

            logger.info(
                f"Pairing code created: couple_id={couple_id}, device_id={payload.device_id}"
            )

            response_data = schemas.PairingResponse(
                couple_id=couple_id,
                device_id=payload.device_id,
                role="creator",
                existing_devices=None,
                auth_token=auth_token,
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
            # Create a DeviceLocation record for the joining device so the
            # couple is immediately at 2 devices and no third device can join.
            auth_token = crud.generate_auth_token()

            from app.models import DeviceLocation
            from datetime import datetime, timezone as tz
            joiner_record = DeviceLocation(
                id=f"{payload.couple_id}:{payload.device_id}",
                couple_id=payload.couple_id,
                device_id=payload.device_id,
                latitude=None,
                longitude=None,
                updated_at=datetime.now(tz.utc),
                is_sharing=False,
                token_hash=crud.hash_token(auth_token),
            )
            db.add(joiner_record)
            db.commit()

            logger.info(
                f"Device joined couple: couple_id={payload.couple_id}, "
                f"device_id={payload.device_id}, existing_devices={device_count}"
            )

            response_data = schemas.PairingResponse(
                couple_id=payload.couple_id,
                device_id=payload.device_id,
                role="partner",
                existing_devices=device_count,
                auth_token=auth_token,
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
        # Verify the couple/device exists and the caller holds its token
        authenticate_device(db, request, payload.couple_id, payload.device_id)

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

    except HTTPException:
        raise

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
        # Verify the caller is a registered device of this couple and holds
        # its token. Without this, anyone who learns a couple code could
        # read the partner's live coordinates.
        authenticate_device(db, request, couple_id, device_id)

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

        # Case 2: Partner not sharing location (or hasn't sent coordinates yet)
        if not partner.is_sharing or partner.latitude is None or partner.longitude is None:
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

    except HTTPException:
        raise

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
# Unpair Route
# ============================================================================

@app.delete("/api/pair/{couple_id}")
@limiter.limit("5/minute")
def delete_pair(
    request: Request,
    couple_id: str,
    device_id: str,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    Unpair a couple, deleting all associated data.

    Requires the caller's device_id as a query parameter to verify
    they are part of the couple.
    """
    try:
        # Verify the caller is a registered device of this couple and holds
        # its token (unpairing deletes the partner's data too)
        authenticate_device(db, request, couple_id, device_id)

        deleted = crud.delete_couple(db, couple_id)
        logger.info(f"Couple unpaired: couple_id={couple_id}, by device_id={device_id}")

        return JSONResponse(content={
            "success": True,
            "message": "Successfully unpaired",
            "devices_removed": deleted,
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error unpairing couple {couple_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to unpair")


# ============================================================================
# Poke Routes
# ============================================================================

def _deliver_poke_push(couple_id: str, sender_device_id: str, message: str | None) -> None:
    """Background task: push the poke to the partner's phone via APNs."""
    from app import push
    from app.database import SessionLocal

    if not push.is_configured():
        return

    db = SessionLocal()
    try:
        tokens = crud.get_partner_push_tokens(db, couple_id, sender_device_id)
        dead = push.send_poke_push(tokens, message)
        crud.delete_push_tokens(db, dead)
    except Exception as e:
        logger.warning(f"Poke push delivery failed (non-fatal): {e}")
    finally:
        db.close()


@app.post("/poke", responses={200: {"model": schemas.PokeResponse}})
@limiter.limit("10/minute")
def send_poke(
    request: Request,
    payload: schemas.PokeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """Send a poke (optionally with a personal message) to your partner."""
    try:
        # Verify the caller is a registered device of this couple
        authenticate_device(db, request, payload.couple_id, payload.device_id)

        crud.create_poke(db, payload.couple_id, payload.device_id, payload.message)

        # Deliver via APNs after the response is sent (no-op if unconfigured)
        background_tasks.add_task(
            _deliver_poke_push, payload.couple_id, payload.device_id, payload.message
        )
        return JSONResponse(content={"success": True, "message": "Poke sent!"})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending poke: {e}")
        raise HTTPException(status_code=500, detail="Failed to send poke")


@app.post("/push/register")
@limiter.limit("10/minute")
def register_push_token(
    request: Request,
    payload: schemas.PushRegisterRequest,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """
    Register (or refresh) a device's APNs push token.

    Requires the device's bearer token. The partner's pokes are then
    delivered as real push notifications even when the app is closed.
    """
    try:
        authenticate_device(db, request, payload.couple_id, payload.device_id)
        crud.upsert_push_token(
            db, payload.couple_id, payload.device_id,
            payload.push_token, payload.platform,
        )
        return JSONResponse(content={"success": True})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error registering push token: {e}")
        raise HTTPException(status_code=500, detail="Failed to register push token")


@app.get("/pokes", responses={200: {"model": schemas.PokesResponse}})
@limiter.limit("30/minute")
def get_pokes(
    request: Request,
    couple_id: str,
    device_id: str,
    db: Session = Depends(get_db),
) -> JSONResponse:
    """Get unseen pokes for this device (marks them as seen)."""
    try:
        # Verify the caller is a registered device of this couple
        authenticate_device(db, request, couple_id, device_id)

        pokes = crud.get_and_clear_unseen_pokes(db, couple_id, device_id)

        def _iso(dt: datetime) -> str:
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.isoformat().replace("+00:00", "Z")

        data = {
            "pokes": len(pokes),
            "latest_at": _iso(max(p.created_at for p in pokes)) if pokes else None,
            "messages": [
                {"message": p.message, "created_at": _iso(p.created_at)}
                for p in pokes
            ],
        }
        return JSONResponse(content=data)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting pokes: {e}")
        raise HTTPException(status_code=500, detail="Failed to get pokes")


# ============================================================================
# Invite Landing Page & Universal Links
# ============================================================================
import re
from fastapi.responses import HTMLResponse

from app.invite import render_invite_page

_PAIRING_CODE_RE = re.compile(r"^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$")


@app.get("/join/{code}", response_class=HTMLResponse)
@limiter.limit("30/minute")
def join_landing(request: Request, code: str) -> HTMLResponse:
    """
    Invite landing page for a pairing code.

    Shared as an https link so it works everywhere (iMessage, WhatsApp,
    email). Opens the native app if installed, otherwise falls back to the
    App Store or the web app. Deliberately does NOT check whether the code
    exists — that would let anyone probe for valid codes.
    """
    normalized = code.strip().upper()
    if not _PAIRING_CODE_RE.match(normalized):
        raise HTTPException(status_code=404, detail="Invalid invite link")

    return HTMLResponse(
        content=render_invite_page(normalized, settings.APP_STORE_URL)
    )


@app.get("/.well-known/apple-app-site-association")
def apple_app_site_association() -> JSONResponse:
    """
    Universal Links support: lets iOS open https://<host>/join/* directly
    in the app. Requires APPLE_TEAM_ID to be configured and the Associated
    Domains capability in the app; returns 404 until then.
    """
    if not settings.APPLE_TEAM_ID:
        raise HTTPException(status_code=404, detail="Not configured")

    app_id = f"{settings.APPLE_TEAM_ID}.{settings.IOS_BUNDLE_ID}"
    return JSONResponse(content={
        "applinks": {
            "apps": [],
            "details": [{"appID": app_id, "paths": ["/join/*"]}],
        }
    })


# ============================================================================
# Static Files (must be last - catches all unmatched routes)
# ============================================================================
import os
_static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.isdir(_static_dir):
    app.mount("/", StaticFiles(directory=_static_dir, html=True), name="static")
