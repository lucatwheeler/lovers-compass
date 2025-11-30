"""
CRUD Operations for Location Data

This module contains database operation functions for managing device locations.
All functions use SQLAlchemy sessions and maintain privacy by not logging coordinates.

Privacy Note: No latitude/longitude values are logged in this module.
Only couple_id, device_id, and success/failure states are logged.
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.models import DeviceLocation
from app.schemas import LocationUpdateRequest

logger = logging.getLogger(__name__)


def upsert_device_location(
    db: Session,
    data: LocationUpdateRequest
) -> DeviceLocation:
    """
    Create or update a device's location record.

    This function implements an "upsert" pattern: if a location record
    already exists for this couple_id:device_id combination, it updates
    the existing record. Otherwise, it creates a new record.

    Privacy: Only the most recent location is stored. No historical data is retained.

    Args:
        db: SQLAlchemy database session
        data: Location update request with couple_id, device_id, coordinates, and sharing status

    Returns:
        DeviceLocation: The created or updated location record

    Raises:
        SQLAlchemyError: If database operation fails
    """
    # Build composite ID from couple_id and device_id
    composite_id = f"{data.couple_id}:{data.device_id}"

    try:
        # Try to fetch existing record
        device = db.query(DeviceLocation).filter(
            DeviceLocation.id == composite_id
        ).first()

        if device:
            # Update existing record
            logger.info(
                f"Updating location for couple_id={data.couple_id}, "
                f"device_id={data.device_id}"
            )

            device.latitude = data.latitude
            device.longitude = data.longitude
            device.is_sharing = data.is_sharing
            device.updated_at = datetime.now(timezone.utc)

        else:
            # Create new record
            logger.info(
                f"Creating new location for couple_id={data.couple_id}, "
                f"device_id={data.device_id}"
            )

            device = DeviceLocation(
                id=composite_id,
                couple_id=data.couple_id,
                device_id=data.device_id,
                latitude=data.latitude,
                longitude=data.longitude,
                updated_at=datetime.now(timezone.utc),
                is_sharing=data.is_sharing
            )
            db.add(device)

        # Commit changes and refresh to get updated data
        db.commit()
        db.refresh(device)

        logger.debug(
            f"Location upsert successful for couple_id={data.couple_id}, "
            f"device_id={data.device_id}"
        )

        return device

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during location upsert for couple_id={data.couple_id}, "
            f"device_id={data.device_id}: {str(e)}"
        )
        db.rollback()
        raise


def get_partner_location(
    db: Session,
    couple_id: str,
    caller_device_id: str
) -> Optional[DeviceLocation]:
    """
    Retrieve the partner's location for a given couple.

    This function finds the location record for the OTHER device in the couple
    (i.e., not the caller's device). If only one device exists or no partner
    has registered yet, returns None.

    Args:
        db: SQLAlchemy database session
        couple_id: Unique identifier for the couple
        caller_device_id: Device ID of the requester (to exclude from results)

    Returns:
        DeviceLocation | None: Partner's location record, or None if no partner exists

    Raises:
        SQLAlchemyError: If database operation fails
    """
    try:
        # Query all devices for this couple, excluding the caller
        partner = db.query(DeviceLocation).filter(
            DeviceLocation.couple_id == couple_id,
            DeviceLocation.device_id != caller_device_id
        ).first()

        if partner:
            logger.debug(
                f"Partner location found for couple_id={couple_id}, "
                f"caller_device_id={caller_device_id}"
            )
        else:
            logger.debug(
                f"No partner location found for couple_id={couple_id}, "
                f"caller_device_id={caller_device_id}"
            )

        return partner

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during partner location retrieval for "
            f"couple_id={couple_id}: {str(e)}"
        )
        raise


def count_devices_for_couple(db: Session, couple_id: str) -> int:
    """
    Count the number of devices registered for a couple.

    This function is primarily used for validation and monitoring.
    In future phases, it will be used to enforce the 2-device limit per couple.

    Args:
        db: SQLAlchemy database session
        couple_id: Unique identifier for the couple

    Returns:
        int: Number of devices registered for this couple

    Raises:
        SQLAlchemyError: If database operation fails
    """
    try:
        count = db.query(DeviceLocation).filter(
            DeviceLocation.couple_id == couple_id
        ).count()

        logger.debug(f"Device count for couple_id={couple_id}: {count}")

        return count

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during device count for couple_id={couple_id}: {str(e)}"
        )
        raise


def get_all_devices_for_couple(db: Session, couple_id: str) -> list[DeviceLocation]:
    """
    Retrieve all device location records for a couple.

    This helper function is useful for debugging and future features.
    It returns all devices registered under the given couple_id.

    Args:
        db: SQLAlchemy database session
        couple_id: Unique identifier for the couple

    Returns:
        list[DeviceLocation]: List of all device location records for the couple

    Raises:
        SQLAlchemyError: If database operation fails
    """
    try:
        devices = db.query(DeviceLocation).filter(
            DeviceLocation.couple_id == couple_id
        ).all()

        logger.debug(
            f"Retrieved {len(devices)} devices for couple_id={couple_id}"
        )

        return devices

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during device retrieval for couple_id={couple_id}: {str(e)}"
        )
        raise
