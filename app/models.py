"""
SQLAlchemy Database Models

Defines the data models for the Lover's Compass application.

Note: This file contains only the model definitions. CRUD operations
and business logic will be added in separate modules in future phases.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, DateTime, Boolean, Index, Integer

from app.database import Base


class DeviceLocation(Base):
    """
    Stores the latest location for each device in a couple pairing.

    Each couple can have up to two devices. The composite id ensures
    each couple-device combination has exactly one location record,
    which gets updated on each location sync.

    Privacy note: Only the most recent location is stored. No historical
    location data is retained.

    Attributes:
        id: Composite primary key in format "{couple_id}:{device_id}"
        couple_id: 8-character pairing code shared by both devices
        device_id: Unique identifier for the device (UUID)
        latitude: Latitude coordinate (-90 to 90)
        longitude: Longitude coordinate (-180 to 180)
        updated_at: Timestamp of last location update (UTC)
        is_sharing: Whether the device is currently sharing location
    """

    __tablename__ = "device_locations"

    # Composite primary key: {couple_id}:{device_id}
    # Example: "ABC123XY:550e8400-e29b-41d4-a716-446655440000"
    id = Column(
        String,
        primary_key=True,
        nullable=False,
        comment="Composite key in format {couple_id}:{device_id}"
    )

    # 8-character alphanumeric pairing code
    couple_id = Column(
        String(8),
        nullable=False,
        index=True,
        comment="8-character pairing code shared by couple"
    )

    # UUID v4 generated client-side
    device_id = Column(
        String(36),
        nullable=False,
        comment="Unique device identifier (UUID)"
    )

    # Location coordinates
    latitude = Column(
        Float,
        nullable=True,
        comment="Latitude coordinate (-90 to 90)"
    )

    longitude = Column(
        Float,
        nullable=True,
        comment="Longitude coordinate (-180 to 180)"
    )

    # Timestamp of last update (UTC)
    # Using timezone-aware datetime instead of deprecated utcnow()
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
        comment="Last location update timestamp (UTC)"
    )

    # Privacy control flag
    is_sharing = Column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether device is currently sharing location"
    )

    # Composite index for efficient couple-device lookups
    __table_args__ = (
        Index('idx_couple_device', 'couple_id', 'device_id', unique=True),
    )

    def __repr__(self) -> str:
        """String representation for debugging."""
        return (
            f"<DeviceLocation(id={self.id}, "
            f"couple_id={self.couple_id}, "
            f"is_sharing={self.is_sharing}, "
            f"updated_at={self.updated_at})>"
        )


class Poke(Base):
    """
    Stores poke notifications between paired devices.

    When one partner sends a poke, a record is created. The recipient
    polls for unseen pokes and they are marked as seen after retrieval.
    """

    __tablename__ = "pokes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    couple_id = Column(String(8), nullable=False, index=True)
    from_device_id = Column(String(100), nullable=False)
    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    seen = Column(Boolean, default=False, nullable=False)
