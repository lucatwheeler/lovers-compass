"""
Lover's Compass - FastAPI Application

Main application entry point with FastAPI configuration, middleware,
and route definitions.

This initial version provides:
- Health check endpoint
- CORS middleware for iOS app
- Database initialization on startup
- Centralized logging configuration

Location-based endpoints will be added in future phases.
"""

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.config import get_settings, Settings
from app.database import get_db, init_db
from app.logging_config import setup_logging

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
    version="0.1.0",
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
# Routes
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
        "version": "0.1.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health"
    }


# ============================================================================
# Dependency Injection Examples
# ============================================================================
# The following commented examples show how to use dependency injection
# for database sessions and settings in future endpoints:
#
# Example 1: Using database session
# @app.get("/example-db")
# async def example_with_db(db: Session = Depends(get_db)):
#     """Example endpoint using database session."""
#     # Use db.query(...) here
#     pass
#
# Example 2: Using settings
# @app.get("/example-config")
# async def example_with_config(settings: Settings = Depends(get_settings)):
#     """Example endpoint using application settings."""
#     # Access settings.ENV, settings.DATABASE_URL, etc.
#     pass
#
# Example 3: Using both
# @app.post("/example-combined")
# async def example_combined(
#     db: Session = Depends(get_db),
#     settings: Settings = Depends(get_settings)
# ):
#     """Example endpoint using both database and settings."""
#     pass


# ============================================================================
# Future Endpoints (To be implemented in next phase)
# ============================================================================
# POST /pair - Generate or validate pairing codes
# POST /updateLocation - Update device location
# GET /partnerLocation - Retrieve partner's location
