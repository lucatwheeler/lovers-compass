"""
Pydantic Schemas for Request/Response Validation

These schemas define the structure of data sent to and returned from
the API endpoints. Pydantic automatically validates incoming requests
and serializes outgoing responses.
"""

from datetime import datetime
from typing import Optional
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
        """Ensure coordinates are valid numbers (not NaN or infinity)."""
        if not isinstance(v, (int, float)):
            raise ValueError('Coordinate must be a number')
        if v != v:  # Check for NaN
            raise ValueError('Coordinate cannot be NaN')
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
