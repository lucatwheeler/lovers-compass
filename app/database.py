"""
Database Configuration and Session Management

Sets up SQLAlchemy engine, session factory, and base model class.
Provides dependency injection for database sessions in FastAPI routes.

Note: For production with PostgreSQL or other databases, update the
DATABASE_URL in your .env file. SQLite requires special connect_args
for thread safety.

Future enhancement: Add Alembic for database migrations if schema
changes become frequent.
"""

from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

from app.config import get_settings

settings = get_settings()

# SQLite-specific configuration for thread safety
# Remove connect_args when using PostgreSQL or other databases
connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

# Create SQLAlchemy engine
# echo=True in development for SQL query logging (disable in production)
engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=settings.is_development,  # Log SQL queries in development
    pool_pre_ping=True,  # Verify connections before using them
)

# Create session factory
# autocommit=False: Require explicit session.commit()
# autoflush=False: Require explicit session.flush()
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base class for all SQLAlchemy models
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency for database session injection.

    Provides a database session for the duration of a request,
    automatically closing it when the request completes.

    Usage in FastAPI routes:
        @app.get("/example")
        def example(db: Session = Depends(get_db)):
            # Use db session here
            pass

    Yields:
        Session: SQLAlchemy database session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Initialize database by creating all tables.

    This should be called during application startup.
    Creates tables based on all models that inherit from Base.

    Note: This is a simple approach for development. For production,
    consider using Alembic migrations for better version control of
    schema changes.
    """
    # Import models to ensure they are registered with Base
    # This must happen before create_all is called
    from app import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
