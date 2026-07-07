"""
Tests for device token auth, poke messages, and invite links.

Covers:
- Tokens issued on pair (create and join)
- Location/poke/unpair endpoints require a valid Bearer token
- Legacy devices (no token on file) still work and can claim a token once
- Poke messages travel end-to-end and are sanitized
- /join/{code} invite landing page
"""

from app.models import DeviceLocation

from tests.conftest import TestingSessionLocal


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def make_couple(client):
    """Create and join a couple; return (couple_id, token_a, token_b)."""
    r = client.post("/pair", json={"action": "create", "device_id": "dev-A"})
    assert r.status_code == 200
    couple_id = r.json()["couple_id"]
    token_a = r.json()["auth_token"]
    r = client.post("/pair", json={
        "action": "join", "couple_id": couple_id, "device_id": "dev-B"
    })
    assert r.status_code == 200
    token_b = r.json()["auth_token"]
    return couple_id, token_a, token_b


# ============================================================================
# Token issuance
# ============================================================================

class TestTokenIssuance:
    def test_create_returns_token(self, client):
        r = client.post("/pair", json={"action": "create", "device_id": "d1"})
        token = r.json()["auth_token"]
        assert token and len(token) >= 32

    def test_join_returns_token(self, client):
        couple_id, token_a, token_b = make_couple(client)
        assert token_a != token_b

    def test_token_stored_hashed(self, client):
        couple_id, token_a, _ = make_couple(client)
        db = TestingSessionLocal()
        try:
            record = db.query(DeviceLocation).filter(
                DeviceLocation.id == f"{couple_id}:dev-A"
            ).one()
            assert record.token_hash is not None
            assert token_a not in record.token_hash
        finally:
            db.close()


# ============================================================================
# Auth enforcement
# ============================================================================

class TestAuthEnforcement:
    def test_update_location_requires_token(self, client):
        couple_id, token_a, _ = make_couple(client)
        body = {
            "couple_id": couple_id, "device_id": "dev-A",
            "latitude": 1.0, "longitude": 2.0, "is_sharing": True,
        }
        assert client.post("/updateLocation", json=body).status_code == 401
        assert client.post(
            "/updateLocation", json=body, headers=auth("wrong")
        ).status_code == 401
        assert client.post(
            "/updateLocation", json=body, headers=auth(token_a)
        ).status_code == 200

    def test_partner_location_requires_token(self, client):
        couple_id, token_a, token_b = make_couple(client)
        client.post("/updateLocation", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "latitude": 1.0, "longitude": 2.0, "is_sharing": True,
        }, headers=auth(token_a))

        params = {"couple_id": couple_id, "device_id": "dev-B"}
        assert client.get("/partnerLocation", params=params).status_code == 401
        r = client.get("/partnerLocation", params=params, headers=auth(token_b))
        assert r.status_code == 200
        assert r.json()["latitude"] == 1.0

    def test_unknown_device_is_404(self, client):
        """An attacker who only knows the couple code gets nothing."""
        couple_id, _, _ = make_couple(client)
        r = client.get("/partnerLocation", params={
            "couple_id": couple_id, "device_id": "attacker-device"
        })
        assert r.status_code == 404

    def test_cross_device_token_rejected(self, client):
        """Device B's token cannot act as device A."""
        couple_id, _, token_b = make_couple(client)
        r = client.post("/updateLocation", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "latitude": 1.0, "longitude": 2.0, "is_sharing": True,
        }, headers=auth(token_b))
        assert r.status_code == 401


# ============================================================================
# Legacy devices (paired before tokens existed)
# ============================================================================

class TestLegacyDevices:
    def _make_legacy_device(self, couple_id="LEGACY22", device_id="old-dev"):
        db = TestingSessionLocal()
        try:
            from datetime import datetime, timezone
            db.add(DeviceLocation(
                id=f"{couple_id}:{device_id}",
                couple_id=couple_id,
                device_id=device_id,
                latitude=None, longitude=None,
                updated_at=datetime.now(timezone.utc),
                is_sharing=False,
                token_hash=None,
            ))
            db.commit()
        finally:
            db.close()
        return couple_id, device_id

    def test_legacy_device_still_works_without_token(self, client):
        couple_id, device_id = self._make_legacy_device()
        r = client.post("/updateLocation", json={
            "couple_id": couple_id, "device_id": device_id,
            "latitude": 1.0, "longitude": 2.0, "is_sharing": True,
        })
        assert r.status_code == 200

    def test_legacy_device_can_claim_token_once(self, client):
        couple_id, device_id = self._make_legacy_device()
        r = client.post("/auth/token", json={
            "couple_id": couple_id, "device_id": device_id
        })
        assert r.status_code == 200
        token = r.json()["auth_token"]

        # Second claim is rejected
        r = client.post("/auth/token", json={
            "couple_id": couple_id, "device_id": device_id
        })
        assert r.status_code == 409

        # After claiming, the token is enforced
        body = {
            "couple_id": couple_id, "device_id": device_id,
            "latitude": 1.0, "longitude": 2.0, "is_sharing": True,
        }
        assert client.post("/updateLocation", json=body).status_code == 401
        assert client.post(
            "/updateLocation", json=body, headers=auth(token)
        ).status_code == 200

    def test_claim_unknown_device_is_404(self, client):
        r = client.post("/auth/token", json={
            "couple_id": "NOPE2345", "device_id": "ghost"
        })
        assert r.status_code == 404


# ============================================================================
# Poke messages
# ============================================================================

class TestPokeMessages:
    def test_poke_message_roundtrip(self, client):
        couple_id, token_a, token_b = make_couple(client)

        r = client.post("/poke", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "message": "miss you, see you at 7 💕",
        }, headers=auth(token_a))
        assert r.status_code == 200

        r = client.get("/pokes", params={
            "couple_id": couple_id, "device_id": "dev-B"
        }, headers=auth(token_b))
        data = r.json()
        assert data["pokes"] == 1
        assert data["messages"][0]["message"] == "miss you, see you at 7 💕"
        assert data["latest_at"] is not None

        # Marked as seen: second fetch is empty
        r = client.get("/pokes", params={
            "couple_id": couple_id, "device_id": "dev-B"
        }, headers=auth(token_b))
        assert r.json()["pokes"] == 0
        assert r.json()["messages"] == []

    def test_poke_without_message(self, client):
        couple_id, token_a, token_b = make_couple(client)
        client.post("/poke", json={
            "couple_id": couple_id, "device_id": "dev-A"
        }, headers=auth(token_a))
        data = client.get("/pokes", params={
            "couple_id": couple_id, "device_id": "dev-B"
        }, headers=auth(token_b)).json()
        assert data["pokes"] == 1
        assert data["messages"][0]["message"] is None

    def test_poke_message_sanitized(self, client):
        couple_id, token_a, token_b = make_couple(client)
        client.post("/poke", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "message": "  hi\x00\x07 there  ",
        }, headers=auth(token_a))
        data = client.get("/pokes", params={
            "couple_id": couple_id, "device_id": "dev-B"
        }, headers=auth(token_b)).json()
        assert data["messages"][0]["message"] == "hi there"

    def test_poke_message_too_long_rejected(self, client):
        couple_id, token_a, _ = make_couple(client)
        r = client.post("/poke", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "message": "x" * 241,
        }, headers=auth(token_a))
        assert r.status_code == 422

    def test_poke_requires_membership(self, client):
        couple_id, _, _ = make_couple(client)
        r = client.post("/poke", json={
            "couple_id": couple_id, "device_id": "stranger",
            "message": "spam",
        })
        assert r.status_code == 404

    def test_pokes_ordered_oldest_first(self, client):
        couple_id, token_a, token_b = make_couple(client)
        for msg in ["first", "second", "third"]:
            client.post("/poke", json={
                "couple_id": couple_id, "device_id": "dev-A", "message": msg,
            }, headers=auth(token_a))
        data = client.get("/pokes", params={
            "couple_id": couple_id, "device_id": "dev-B"
        }, headers=auth(token_b)).json()
        assert [m["message"] for m in data["messages"]] == [
            "first", "second", "third"
        ]


# ============================================================================
# Invite landing page
# ============================================================================

class TestInvitePage:
    def test_valid_code_renders(self, client):
        r = client.get("/join/ABCD2345")
        assert r.status_code == 200
        assert "ABCD2345" in r.text
        assert "loverscompass://join/" in r.text

    def test_lowercase_code_normalized(self, client):
        r = client.get("/join/abcd2345")
        assert r.status_code == 200
        assert "ABCD2345" in r.text

    def test_invalid_codes_rejected(self, client):
        for bad in ["short", "ABCD23456", "ABCD234O", "<script>", "ABCD 345"]:
            assert client.get(f"/join/{bad}").status_code == 404

    def test_page_does_not_reveal_code_validity(self, client):
        """Page renders identically whether or not the couple exists."""
        couple_id, _, _ = make_couple(client)
        real = client.get(f"/join/{couple_id}")
        fake = client.get("/join/ZZZZ9999")
        assert real.status_code == fake.status_code == 200


# ============================================================================
# Push token registration
# ============================================================================

class TestPushRegistration:
    def test_register_requires_auth(self, client):
        couple_id, token_a, _ = make_couple(client)
        body = {
            "couple_id": couple_id, "device_id": "dev-A",
            "push_token": "a" * 64,
        }
        assert client.post("/push/register", json=body).status_code == 401
        assert client.post(
            "/push/register", json=body, headers=auth(token_a)
        ).status_code == 200

    def test_register_upserts(self, client):
        from app.models import PushToken
        couple_id, token_a, _ = make_couple(client)
        for push_token in ["a" * 64, "b" * 64]:
            client.post("/push/register", json={
                "couple_id": couple_id, "device_id": "dev-A",
                "push_token": push_token,
            }, headers=auth(token_a))

        db = TestingSessionLocal()
        try:
            rows = db.query(PushToken).filter(
                PushToken.couple_id == couple_id
            ).all()
            assert len(rows) == 1
            assert rows[0].token == "b" * 64
        finally:
            db.close()

    def test_poke_schedules_push_to_partner(self, client, monkeypatch):
        """Poke triggers a background push to the partner's token only."""
        import app.main as main_mod
        from app import push as push_mod

        couple_id, token_a, token_b = make_couple(client)

        # Register push tokens for both devices
        for dev, tok, ptok in [("dev-A", token_a, "a" * 64), ("dev-B", token_b, "b" * 64)]:
            client.post("/push/register", json={
                "couple_id": couple_id, "device_id": dev, "push_token": ptok,
            }, headers=auth(tok))

        sent = {}
        monkeypatch.setattr(push_mod, "is_configured", lambda: True)
        monkeypatch.setattr(
            push_mod, "send_poke_push",
            lambda tokens, message: sent.update(tokens=tokens, message=message) or [],
        )
        # Background task uses app.database.SessionLocal; point it at the test engine
        import app.database as db_mod
        from tests.conftest import TestingSessionLocal as TSL
        monkeypatch.setattr(db_mod, "SessionLocal", TSL)

        r = client.post("/poke", json={
            "couple_id": couple_id, "device_id": "dev-A",
            "message": "pushed note 💌",
        }, headers=auth(token_a))
        assert r.status_code == 200

        # TestClient runs background tasks before returning
        assert sent["tokens"] == ["b" * 64]
        assert sent["message"] == "pushed note 💌"

    def test_unpair_removes_push_tokens(self, client):
        from app.models import PushToken
        couple_id, token_a, _ = make_couple(client)
        client.post("/push/register", json={
            "couple_id": couple_id, "device_id": "dev-A", "push_token": "c" * 64,
        }, headers=auth(token_a))

        client.delete(
            f"/api/pair/{couple_id}", params={"device_id": "dev-A"},
            headers=auth(token_a),
        )
        db = TestingSessionLocal()
        try:
            assert db.query(PushToken).filter(
                PushToken.couple_id == couple_id
            ).count() == 0
        finally:
            db.close()
