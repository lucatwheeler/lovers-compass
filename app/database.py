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

# Create SQLAlchemy engine with production-ready connection pooling
# echo=True in development for SQL query logging (disable in production)
engine_config = {
    "connect_args": connect_args,
    "echo": settings.is_development,  # Log SQL queries in development
    "pool_pre_ping": True,  # Verify connections before using them
}

# Add connection pool configuration for non-SQLite databases
# SQLite uses in-memory pooling automatically
if not settings.DATABASE_URL.startswith("sqlite"):
    engine_config.update({
        "pool_size": 10,           # Base connection pool size
        "max_overflow": 20,        # Additional connections under load
        "pool_timeout": 30,        # Wait 30s for connection
        "pool_recycle": 3600,      # Recycle connections after 1 hour
    })

engine = create_engine(settings.DATABASE_URL, **engine_config)

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
    _run_column_migrations()


def _run_column_migrations() -> None:
    """
    Add columns that create_all() cannot add to pre-existing tables.

    create_all() only creates missing tables; it never alters existing ones.
    This keeps the live database in sync when a deploy adds a column.
    """
    from sqlalchemy import inspect, text

    migrations = {
        "device_locations": [("token_hash", "VARCHAR(64)")],
        "pokes": [("message", "VARCHAR(240)")],
    }

    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    with engine.begin() as conn:
        for table, columns in migrations.items():
            if table not in existing_tables:
                continue
            existing_cols = {c["name"] for c in inspector.get_columns(table)}
            for name, ddl_type in columns:
                if name not in existing_cols:
                    conn.execute(
                        text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl_type}")
                    )
