"""
Shared pytest fixtures.

A single test engine + dependency override lives here. Individual test
modules must NOT override app.dependency_overrides themselves — the
override is process-global, so two modules doing it independently means
one module's tests silently run against the other's engine.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.database import Base, get_db
from app.rate_limit import limiter, device_limiter_query

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    database = TestingSessionLocal()
    try:
        yield database
    finally:
        database.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_database():
    """Fresh tables and reset rate limits for every test."""
    Base.metadata.create_all(bind=engine)
    limiter.reset()
    device_limiter_query.reset()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c
