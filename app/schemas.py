"""
Pydantic Schemas for Request/Response Validation

These schemas define the structure of data sent to and returned from
the API endpoints. Pydantic automatically validates incoming requests
and serializes outgoing responses.
"""

from datetime import datetime
from typing import Optional, Literal
import re
from pydantic import BaseModel, Field, field_validator


class LocationUpdateRequest(BaseModel):
    """
    Request schema for updating a device's location.

    This schema is used for the POST /updateLocation endpoint.
    Each device sends its current location along with couple_id and device_id.
    """

    couple_id: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Unique identifier for the couple (pairing code)"
    )

    device_id: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Unique identifier for this device (UUID)"
    )

    latitude: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
        description="Latitude coordinate (-90 to 90)"
    )

    longitude: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
        description="Longitude coordinate (-180 to 180)"
    )

    is_sharing: bool = Field(
        default=True,
        description="Whether the device is currently sharing location"
    )

    @field_validator('latitude', 'longitude')
    @classmethod
    def validate_coordinates(cls, v: float) -> float:
        """
        Ensure coordinates are valid numbers (not NaN or infinity).

        Phase 4 Enhancement: Added infinity check for security hardening.
        """
        if not isinstance(v, (int, float)):
            raise ValueError('Coordinate must be a number')
        if v != v:  # Check for NaN
            raise ValueError('Coordinate cannot be NaN')
        if not (-float('inf') < v < float('inf')):  # Check for infinity
            raise ValueError('Coordinate cannot be infinity')
        return float(v)

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "couple_id": "ABC123XY",
                    "device_id": "550e8400-e29b-41d4-a716-446655440000",
                    "latitude": 37.7749,
                    "longitude": -122.4194,
                    "is_sharing": True
                }
            ]
        }
    }


class LocationUpdateResponse(BaseModel):
    """
    Response schema for location update requests.

    Confirms that the location was successfully updated and provides
    the timestamp of the update.
    """

    success: bool = Field(
        ...,
        description="Whether the location update was successful"
    )

    updated_at: datetime = Field(
        ...,
        description="UTC timestamp of when the location was updated"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "success": True,
                    "updated_at": "2025-11-29T12:34:56.789Z"
                }
            ]
        }
    }


class PartnerLocationResponse(BaseModel):
    """
    Response schema for retrieving partner's location.

    This schema supports three scenarios:
    1. No partner found yet (partner_found=False)
    2. Partner found but not sharing (is_sharing=False)
    3. Partner found and sharing (is_sharing=True, with coordinates)
    """

    partner_found: bool = Field(
        ...,
        description="Whether a partner device exists for this couple"
    )

    is_sharing: Optional[bool] = Field(
        default=None,
        description="Whether the partner is currently sharing location"
    )

    latitude: Optional[float] = Field(
        default=None,
        ge=-90.0,
        le=90.0,
        description="Partner's latitude coordinate (only if sharing)"
    )

    longitude: Optional[float] = Field(
        default=None,
        ge=-180.0,
        le=180.0,
        description="Partner's longitude coordinate (only if sharing)"
    )

    updated_at: Optional[datetime] = Field(
        default=None,
        description="UTC timestamp of partner's last location update"
    )

    staleness_seconds: Optional[int] = Field(
        default=None,
        description="Seconds since partner's last location update"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "partner_found": False
                },
                {
                    "partner_found": True,
                    "is_sharing": False,
                    "staleness_seconds": 120
                },
                {
                    "partner_found": True,
                    "is_sharing": True,
                    "latitude": 37.8044,
                    "longitude": -122.2712,
                    "updated_at": "2025-11-29T12:32:56.789Z",
                    "staleness_seconds": 45
                }
            ]
        }
    }


class PairingRequest(BaseModel):
    """
    Request schema for pairing operations.

    Supports two actions:
    - "create": Generate a new couple_id (pairing code)
    - "join": Join an existing couple using a pairing code

    For "create" action, couple_id is ignored.
    For "join" action, couple_id is required.
    """

    action: Literal["create", "join"] = Field(
        ...,
        description="Action to perform: 'create' a new couple or 'join' an existing one"
    )

    device_id: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Unique identifier for this device (UUID)"
    )

    couple_id: Optional[str] = Field(
        default=None,
        min_length=8,
        max_length=8,
        description="Pairing code (required for 'join' action, ignored for 'create')"
    )

    @field_validator('couple_id')
    @classmethod
    def validate_couple_id(cls, v: Optional[str]) -> Optional[str]:
        """
        Validate pairing code format for security.

        Phase 4 Enhancement: Enforce uppercase alphanumeric format.
        Pairing codes must be:
        - 8 characters long
        - Uppercase letters A-Z (excluding O, I)
        - Digits 2-9 (excluding 0, 1)

        Returns None if not provided (for 'create' action).
        Raises ValueError if format is invalid (for 'join' action).
        """
        if v is None:
            return v

        # Must be exactly 8 characters
        if len(v) != 8:
            raise ValueError('Pairing code must be exactly 8 characters')

        # Must be uppercase alphanumeric
        if not v.isupper():
            raise ValueError('Pairing code must be uppercase')

        if not v.isalnum():
            raise ValueError('Pairing code must be alphanumeric')

        # Check for valid characters (A-Z excluding O,I and digits 2-9 excluding 0,1)
        # This matches the generation pattern from crud.py
        allowed_chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        for char in v:
            if char not in allowed_chars:
                raise ValueError(
                    f'Invalid character in pairing code: {char}. '
                    'Pairing codes only use A-Z (excluding O, I) and 2-9 (excluding 0, 1)'
                )

        return v

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "action": "create",
                    "device_id": "550e8400-e29b-41d4-a716-446655440000"
                },
                {
                    "action": "join",
                    "couple_id": "AB12CD34",
                    "device_id": "660f9511-f39c-52e5-b827-557766551111"
                }
            ]
        }
    }


class PokeRequest(BaseModel):
    """Request schema for sending a poke to partner."""

    couple_id: str = Field(..., min_length=1, max_length=100)
    device_id: str = Field(..., min_length=1, max_length=100)


class PokeResponse(BaseModel):
    """Response schema for poke operations."""

    success: bool
    message: str


class PokesResponse(BaseModel):
    """Response schema for retrieving unseen pokes."""

    pokes: int = Field(..., description="Number of unseen pokes")
    latest_at: Optional[datetime] = Field(default=None)


class PairingResponse(BaseModel):
    """
    Response schema for pairing operations.

    Returns the pairing details including the couple_id (pairing code),
    device_id, role (creator or partner), and optionally the count of
    existing devices when joining.
    """

    couple_id: str = Field(
        ...,
        description="The pairing code for this couple"
    )

    device_id: str = Field(
        ...,
        description="The device ID that was paired"
    )

    role: Literal["creator", "partner"] = Field(
        ...,
        description="Role of this device: 'creator' (generated code) or 'partner' (joined)"
    )

    existing_devices: Optional[int] = Field(
        default=None,
        description="Number of devices in couple before this one joined (only for 'join' action)"
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "couple_id": "AB12CD34",
                    "device_id": "550e8400-e29b-41d4-a716-446655440000",
                    "role": "creator",
                    "existing_devices": None
                },
                {
                    "couple_id": "AB12CD34",
                    "device_id": "660f9511-f39c-52e5-b827-557766551111",
                    "role": "partner",
                    "existing_devices": 1
                }
            ]
        }
    }
