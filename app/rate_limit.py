"""
Rate Limiting Configuration for Lover's Compass API

This module configures rate limiting using SlowAPI to protect against:
- Brute force attacks on pairing codes
- API abuse and spam
- Buggy clients flooding the server

Two types of rate limiting:
1. IP-based: Limits requests per IP address
2. Device-based: Limits requests per (couple_id, device_id) combination
"""

import logging
from typing import Callable
from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

logger = logging.getLogger(__name__)


# ============================================================================
# Custom Key Functions for Device-Based Rate Limiting
# ============================================================================

def get_device_key_from_query(request: Request) -> str:
    """
    Extract (couple_id, device_id) from query parameters for rate limiting.

    Used for GET /partnerLocation endpoint.
    Falls back to IP address if extraction fails.

    Args:
        request: FastAPI request object

    Returns:
        str: Rate limit key in format "device:{couple_id}:{device_id}" or IP address
    """
    try:
        couple_id = request.query_params.get('couple_id', '')
        device_id = request.query_params.get('device_id', '')

        if couple_id and device_id:
            key = f"device:{couple_id}:{device_id}"
            logger.debug(f"Rate limit key from query: {key}")
            return key
        else:
            # Fallback to IP if parameters missing
            ip = get_remote_address(request)
            logger.debug(f"Rate limit: Missing query params, using IP: {ip}")
            return ip

    except Exception as e:
        # Fallback to IP on any error
        ip = get_remote_address(request)
        logger.warning(f"Rate limit: Error extracting device key from query: {e}, using IP: {ip}")
        return ip


# ============================================================================
# Limiter Configuration
# ============================================================================

# Initialize the main limiter with IP-based rate limiting as default
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],  # No global default limits, we'll set per-endpoint
    storage_uri="memory://",  # Use in-memory storage (suitable for single-instance deployment)
    strategy="fixed-window",  # Fixed time window strategy
    headers_enabled=True,  # Include X-RateLimit-* headers in responses
)


# ============================================================================
# Rate Limit Decorators
# ============================================================================

# For /pair endpoint
# Prevent brute forcing of pairing codes
PAIR_RATE_LIMIT = "5/minute"  # 5 requests per minute per IP


# For /updateLocation endpoint
# IP-based only: reading the JSON body inside a sync rate-limit key function
# isn't possible, so per-device limiting can't apply here. Sized for two
# clients on the same wifi sending every 5s (24/min) with headroom.
UPDATE_LOCATION_IP_LIMIT = "60/minute"


# For /partnerLocation endpoint
# Device-based (from query params): iOS polls every 10s, the web app every
# 3s (20/min); allow 30/min for buffer.
PARTNER_LOCATION_DEVICE_LIMIT = "30/minute"
# IP-based safety net (two clients on the same wifi share this)
PARTNER_LOCATION_IP_LIMIT = "120/minute"


# ============================================================================
# Helper Functions
# ============================================================================

def create_device_limiter(key_func: Callable) -> Limiter:
    """
    Create a limiter instance with a custom key function.

    Args:
        key_func: Function to extract rate limit key from request

    Returns:
        Limiter: Configured limiter instance
    """
    return Limiter(
        key_func=key_func,
        default_limits=[],
        storage_uri="memory://",
        strategy="fixed-window",
        headers_enabled=True,
    )


# Create device-specific limiter (query-param based endpoints only)
device_limiter_query = create_device_limiter(get_device_key_from_query)


# ============================================================================
# Rate Limit Exceeded Handler
# ============================================================================

def log_rate_limit_exceeded(request: Request, endpoint: str):
    """
    Log rate limit exceeded events without exposing sensitive data.

    Args:
        request: FastAPI request object
        endpoint: Endpoint path that was rate limited
    """
    ip = get_remote_address(request)
    logger.warning(f"Rate limit exceeded on {endpoint} for IP {ip}")
