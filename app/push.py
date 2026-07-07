"""
APNs Push Notifications

Sends poke notifications to the partner's iPhone via Apple Push
Notification service using token-based (JWT / .p8 key) authentication.

Push is optional: if the APNS_* settings are not configured, every function
here is a silent no-op and the app falls back to in-app polling only.

Configuration (environment variables):
    APNS_TEAM_ID      Apple Developer Team ID
    APNS_KEY_ID       Key ID of the APNs auth key
    APNS_PRIVATE_KEY  Full content of the .p8 file ("\\n" escapes accepted)
    APNS_TOPIC        App bundle ID (default com.ltw.lovecompass)
    APNS_USE_SANDBOX  true for development builds (default false)
"""

import logging
import time
from typing import Optional

from app.config import get_settings

logger = logging.getLogger(__name__)

_PROD_HOST = "https://api.push.apple.com"
_SANDBOX_HOST = "https://api.sandbox.push.apple.com"

# APNs JWTs may be reused for up to an hour; refresh after 45 minutes.
_TOKEN_TTL_SECONDS = 45 * 60

_cached_jwt: Optional[str] = None
_cached_jwt_at: float = 0.0


def is_configured() -> bool:
    """Whether APNs credentials are present."""
    s = get_settings()
    return bool(s.APNS_TEAM_ID and s.APNS_KEY_ID and s.APNS_PRIVATE_KEY)


def _provider_jwt() -> str:
    """Return a cached ES256 provider token, minting a new one as needed."""
    global _cached_jwt, _cached_jwt_at

    now = time.time()
    if _cached_jwt and now - _cached_jwt_at < _TOKEN_TTL_SECONDS:
        return _cached_jwt

    import jwt  # PyJWT

    s = get_settings()
    private_key = s.APNS_PRIVATE_KEY.replace("\\n", "\n")
    _cached_jwt = jwt.encode(
        {"iss": s.APNS_TEAM_ID, "iat": int(now)},
        private_key,
        algorithm="ES256",
        headers={"kid": s.APNS_KEY_ID},
    )
    _cached_jwt_at = now
    return _cached_jwt


def send_poke_push(device_tokens: list[str], message: Optional[str]) -> list[str]:
    """
    Send a poke notification to the given APNs device tokens.

    Returns the tokens APNs reported as dead (410 Unregistered /
    BadDeviceToken) so the caller can purge them. Never raises: push is
    best-effort and must not fail the poke request.
    """
    if not device_tokens or not is_configured():
        return []

    import httpx

    s = get_settings()
    host = _SANDBOX_HOST if s.APNS_USE_SANDBOX else _PROD_HOST

    payload = {
        "aps": {
            "alert": {
                "title": "Lover's Compass",
                "body": message or "Your lover is thinking of you! 💕",
            },
            "sound": "default",
        }
    }

    dead_tokens: list[str] = []
    try:
        headers = {
            "authorization": f"bearer {_provider_jwt()}",
            "apns-topic": s.APNS_TOPIC,
            "apns-push-type": "alert",
            "apns-priority": "10",
        }
        with httpx.Client(http2=True, timeout=10) as client:
            for token in device_tokens:
                try:
                    resp = client.post(
                        f"{host}/3/device/{token}",
                        json=payload,
                        headers=headers,
                    )
                    if resp.status_code == 200:
                        logger.info("Poke push delivered")
                    elif resp.status_code in (400, 410) and (
                        "BadDeviceToken" in resp.text or "Unregistered" in resp.text
                    ):
                        logger.info("Purging dead APNs token")
                        dead_tokens.append(token)
                    else:
                        logger.warning(
                            f"APNs push failed: {resp.status_code} {resp.text[:200]}"
                        )
                except httpx.HTTPError as e:
                    logger.warning(f"APNs request error: {e}")
    except Exception as e:
        # Includes JWT minting errors from bad key material
        logger.error(f"APNs push aborted: {e}")

    return dead_tokens
