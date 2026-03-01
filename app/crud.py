"""
CRUD Operations for Location Data

This module contains database operation functions for managing device locations.
All functions use SQLAlchemy sessions and maintain privacy by not logging coordinates.

Privacy Note: No latitude/longitude values are logged in this module.
Only couple_id, device_id, and success/failure states are logged.
"""

import logging
import secrets
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.models import DeviceLocation, Poke
from app.schemas import LocationUpdateRequest

logger = logging.getLogger(__name__)


# ============================================================================
# Pairing Code Generation
# ============================================================================

def _generate_pairing_code() -> str:
    """
    Generate a cryptographically secure 8-character pairing code.

    Uses uppercase letters (A-Z) and digits (2-9) only.
    Excludes ambiguous characters: 0, O, 1, I, l

    Returns:
        str: 8-character uppercase alphanumeric pairing code
    """
    # Allowed characters: A-Z (excluding O and I) and digits 2-9 (excluding 0 and 1)
    allowed_chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # 32 characters total
    return ''.join(secrets.choice(allowed_chars) for _ in range(8))


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


# ============================================================================
# Pairing Functions
# ============================================================================

def generate_unique_couple_id(db: Session) -> str:
    """
    Generate a unique couple_id (pairing code) that doesn't already exist.

    Generates 8-character cryptographically secure codes and checks for
    collisions in the database. Retries until a unique code is found.

    Args:
        db: SQLAlchemy database session

    Returns:
        str: Unique 8-character uppercase alphanumeric pairing code

    Raises:
        SQLAlchemyError: If database operation fails
    """
    max_attempts = 100  # Safety limit to prevent infinite loop
    attempt = 0

    while attempt < max_attempts:
        couple_id = _generate_pairing_code()

        # Check if this couple_id already exists
        count = count_devices_for_couple(db, couple_id)

        if count == 0:
            logger.info(f"Generated unique couple_id (pairing code) on attempt {attempt + 1}")
            return couple_id

        attempt += 1
        logger.debug(f"Pairing code collision on attempt {attempt}, regenerating")

    # This should be extremely unlikely with 32^8 possible combinations
    logger.error("Failed to generate unique couple_id after 100 attempts")
    raise RuntimeError("Failed to generate unique pairing code after maximum attempts")


def create_poke(db: Session, couple_id: str, from_device_id: str) -> Poke:
    """Create a new poke from one device to their partner."""
    try:
        poke = Poke(
            couple_id=couple_id,
            from_device_id=from_device_id,
            created_at=datetime.now(timezone.utc),
        )
        db.add(poke)
        db.commit()
        db.refresh(poke)
        logger.info(f"Poke created: couple_id={couple_id}, from={from_device_id}")
        return poke
    except SQLAlchemyError as e:
        logger.error(f"Database error creating poke: {e}")
        db.rollback()
        raise


def get_and_clear_unseen_pokes(
    db: Session, couple_id: str, for_device_id: str
) -> tuple[int, Optional[datetime]]:
    """
    Get count of unseen pokes for a device and mark them as seen.

    Returns pokes sent BY the partner (from_device_id != for_device_id).
    """
    try:
        pokes = (
            db.query(Poke)
            .filter(
                Poke.couple_id == couple_id,
                Poke.from_device_id != for_device_id,
                Poke.seen == False,
            )
            .all()
        )

        count = len(pokes)
        latest_at = None

        if pokes:
            latest_at = max(p.created_at for p in pokes)
            for p in pokes:
                p.seen = True
            db.commit()

        return count, latest_at
    except SQLAlchemyError as e:
        logger.error(f"Database error getting pokes: {e}")
        db.rollback()
        raise


def delete_couple(db: Session, couple_id: str) -> int:
    """
    Delete all records for a couple (unpair).

    Removes all DeviceLocation and Poke records for the given couple_id.

    Args:
        db: SQLAlchemy database session
        couple_id: Unique identifier for the couple

    Returns:
        int: Number of device records deleted

    Raises:
        SQLAlchemyError: If database operation fails
    """
    try:
        poke_count = db.query(Poke).filter(Poke.couple_id == couple_id).delete()
        device_count = db.query(DeviceLocation).filter(
            DeviceLocation.couple_id == couple_id
        ).delete()
        db.commit()
        logger.info(
            f"Couple deleted: couple_id={couple_id}, "
            f"devices={device_count}, pokes={poke_count}"
        )
        return device_count
    except SQLAlchemyError as e:
        logger.error(f"Database error deleting couple {couple_id}: {e}")
        db.rollback()
        raise


def couple_exists(db: Session, couple_id: str) -> bool:
    """
    Check if a couple_id exists in the database.

    Args:
        db: SQLAlchemy database session
        couple_id: Unique identifier for the couple

    Returns:
        bool: True if at least one device exists for this couple_id, False otherwise

    Raises:
        SQLAlchemyError: If database operation fails
    """
    try:
        count = count_devices_for_couple(db, couple_id)
        exists = count > 0

        logger.debug(f"Couple existence check for couple_id={couple_id}: {exists}")

        return exists

    except SQLAlchemyError as e:
        logger.error(
            f"Database error during couple existence check for couple_id={couple_id}: {str(e)}"
        )
        raise
