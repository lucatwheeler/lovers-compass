"""
Comprehensive Test Suite for Phase 3: Pairing System

Tests the pairing functionality including:
- Pairing code generation (format, uniqueness, security)
- POST /pair CREATE action
- POST /pair JOIN action
- DELETE /api/pair/{couple_id} unpair
- Error handling (404, 409, 400, 500)
- Schema validation
"""

from app import crud

from tests.conftest import TestingSessionLocal


def auth(token: str) -> dict:
    """Authorization header for a device token."""
    return {"Authorization": f"Bearer {token}"}


# ============================================================================
# Test 1: Pairing Code Generation
# ============================================================================

class TestPairingCodeGeneration:
    """Test the pairing code generation logic."""

    def test_code_format(self, client):
        """Test that generated codes match the expected format."""
        db = TestingSessionLocal()
        try:
            code = crud.generate_unique_couple_id(db)

            # Should be 8 characters
            assert len(code) == 8, f"Code length is {len(code)}, expected 8"

            # Should be uppercase alphanumeric
            assert code.isupper(), "Code should be uppercase"
            assert code.isalnum(), "Code should be alphanumeric"

            # Should not contain ambiguous characters
            ambiguous = ['0', 'O', '1', 'I', 'l']
            for char in ambiguous:
                assert char not in code, f"Code contains ambiguous character: {char}"

            # Should only contain allowed characters
            allowed = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            for char in code:
                assert char in allowed, f"Code contains invalid character: {char}"
        finally:
            db.close()

    def test_code_uniqueness(self, client):
        """Test that generated codes are unique."""
        db = TestingSessionLocal()
        try:
            codes = set()
            # Generate 100 codes and verify all are unique
            for _ in range(100):
                code = crud._generate_pairing_code()
                assert code not in codes, f"Duplicate code generated: {code}"
                codes.add(code)
        finally:
            db.close()

    def test_collision_detection(self, client):
        """Test that the system detects and handles collisions."""
        db = TestingSessionLocal()
        try:
            # First code should succeed
            code1 = crud.generate_unique_couple_id(db)
            assert code1 is not None

            # Create a device with this code
            response = client.post("/pair", json={
                "action": "create",
                "device_id": "test-device-1"
            })
            assert response.status_code == 200
            first_code = response.json()["couple_id"]

            # Generate another code - should be different
            code2 = crud.generate_unique_couple_id(db)
            assert code2 != first_code, "Generated code should not collide"
        finally:
            db.close()

    def test_cryptographic_randomness(self, client):
        """Test that codes use cryptographically secure randomness."""
        db = TestingSessionLocal()
        try:
            codes = [crud._generate_pairing_code() for _ in range(50)]

            # Check distribution - should have good character variety
            all_chars = ''.join(codes)
            unique_chars = set(all_chars)

            # With 50 codes (400 characters), we should see good character diversity
            # Expect at least 20 different characters from the 32 available
            assert len(unique_chars) >= 20, f"Poor character distribution: only {len(unique_chars)} unique chars"
        finally:
            db.close()


# ============================================================================
# Test 2: POST /pair CREATE Action
# ============================================================================

class TestPairCreate:
    """Test the CREATE action of the /pair endpoint."""

    def test_create_success(self, client):
        """Test successful couple creation."""
        response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-create-001"
        })

        assert response.status_code == 200
        data = response.json()

        # Verify response structure
        assert "couple_id" in data
        assert "device_id" in data
        assert "role" in data
        assert "existing_devices" in data

        # Verify values
        assert len(data["couple_id"]) == 8
        assert data["device_id"] == "device-create-001"
        assert data["role"] == "creator"
        assert data["existing_devices"] is None

    def test_create_multiple_couples(self, client):
        """Test creating multiple different couples."""
        codes = []

        for i in range(5):
            response = client.post("/pair", json={
                "action": "create",
                "device_id": f"device-{i}"
            })

            assert response.status_code == 200
            data = response.json()
            codes.append(data["couple_id"])

        # All codes should be unique
        assert len(codes) == len(set(codes)), "Duplicate couple_ids generated"

    def test_create_ignores_provided_couple_id(self, client):
        """Test that CREATE action ignores any provided couple_id."""
        response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-ignore-test",
            "couple_id": "ABCDEFGH"  # Valid format but should be ignored
        })

        assert response.status_code == 200
        data = response.json()

        # Should generate new code, not use provided one
        assert data["couple_id"] != "ABCDEFGH"

    def test_create_with_special_device_ids(self, client):
        """Test CREATE with various device_id formats."""
        test_cases = [
            "550e8400-e29b-41d4-a716-446655440000",  # UUID format
            "device-with-dashes",
            "device_with_underscores",
            "DeviceWithCaps123",
            "a",  # Single character
        ]

        for device_id in test_cases:
            response = client.post("/pair", json={
                "action": "create",
                "device_id": device_id
            })

            assert response.status_code == 200, f"Failed for device_id: {device_id}"
            data = response.json()
            assert data["device_id"] == device_id


# ============================================================================
# Test 3: POST /pair JOIN Action
# ============================================================================

class TestPairJoin:
    """Test the JOIN action of the /pair endpoint."""

    def test_join_success(self, client):
        """Test successful joining of an existing couple."""
        # First, create a couple (this now stores a DeviceLocation record)
        create_response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-creator"
        })
        assert create_response.status_code == 200
        couple_id = create_response.json()["couple_id"]

        # Now join as second device (creator already has 1 device record)
        join_response = client.post("/pair", json={
            "action": "join",
            "couple_id": couple_id,
            "device_id": "device-joiner"
        })

        assert join_response.status_code == 200
        data = join_response.json()

        # Verify response
        assert data["couple_id"] == couple_id
        assert data["device_id"] == "device-joiner"
        assert data["role"] == "partner"
        assert data["existing_devices"] == 1

    def test_join_nonexistent_code_404(self, client):
        """Test joining with a non-existent pairing code returns 404."""
        response = client.post("/pair", json={
            "action": "join",
            "couple_id": "ABCDEFGH",
            "device_id": "device-test"
        })

        assert response.status_code == 404
        assert "Pairing code not found" in response.json()["detail"]

    def test_join_full_couple_409(self, client):
        """Test that joining a full couple (2 devices) returns 409."""
        # Create couple (1 device)
        create_response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-1"
        })
        couple_id = create_response.json()["couple_id"]

        # Join as second device (now 2 devices)
        join_response = client.post("/pair", json={
            "action": "join",
            "couple_id": couple_id,
            "device_id": "device-2"
        })
        assert join_response.status_code == 200

        # Try to join as third device - should fail
        response = client.post("/pair", json={
            "action": "join",
            "couple_id": couple_id,
            "device_id": "device-3"
        })

        assert response.status_code == 409
        assert "already paired with 2 devices" in response.json()["detail"]

    def test_join_without_couple_id_400(self, client):
        """Test that JOIN without couple_id returns 400."""
        response = client.post("/pair", json={
            "action": "join",
            "device_id": "device-test"
            # couple_id missing
        })

        assert response.status_code == 400
        assert "couple_id is required" in response.json()["detail"]

    def test_join_same_device_twice(self, client):
        """Test that same device updating location is an upsert."""
        # Create couple
        create_response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-duplicate"
        })
        couple_id = create_response.json()["couple_id"]
        token = create_response.json()["auth_token"]

        # Add device location (updates the existing record from CREATE)
        response1 = client.post("/updateLocation", json={
            "couple_id": couple_id,
            "device_id": "device-duplicate",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "is_sharing": True
        }, headers=auth(token))
        assert response1.status_code == 200

        # Try to add same device again - should update, not create
        response2 = client.post("/updateLocation", json={
            "couple_id": couple_id,
            "device_id": "device-duplicate",
            "latitude": 37.8044,
            "longitude": -122.2712,
            "is_sharing": True
        }, headers=auth(token))
        assert response2.status_code == 200

        # Verify only 1 device exists
        db = TestingSessionLocal()
        try:
            count = crud.count_devices_for_couple(db, couple_id)
            assert count == 1, f"Expected 1 device, found {count}"
        finally:
            db.close()


# ============================================================================
# Test 4: Schema Validation
# ============================================================================

class TestSchemaValidation:
    """Test Pydantic schema validation."""

    def test_invalid_action(self, client):
        """Test that invalid action values are rejected."""
        response = client.post("/pair", json={
            "action": "invalid",
            "device_id": "device-test"
        })

        assert response.status_code == 422  # Pydantic validation error

    def test_missing_device_id(self, client):
        """Test that missing device_id is rejected."""
        response = client.post("/pair", json={
            "action": "create"
            # device_id missing
        })

        assert response.status_code == 422

    def test_empty_device_id(self, client):
        """Test that empty device_id is rejected."""
        response = client.post("/pair", json={
            "action": "create",
            "device_id": ""
        })

        assert response.status_code == 422

    def test_device_id_too_long(self, client):
        """Test that device_id longer than 100 chars is rejected."""
        long_device_id = "x" * 101
        response = client.post("/pair", json={
            "action": "create",
            "device_id": long_device_id
        })

        assert response.status_code == 422

    def test_couple_id_wrong_length(self, client):
        """Test that couple_id with wrong length is rejected."""
        # Too short
        response1 = client.post("/pair", json={
            "action": "join",
            "couple_id": "SHORT",
            "device_id": "device-test"
        })
        assert response1.status_code == 422

        # Too long
        response2 = client.post("/pair", json={
            "action": "join",
            "couple_id": "TOOLONG12",
            "device_id": "device-test"
        })
        assert response2.status_code == 422

    def test_response_schema_structure(self, client):
        """Test that response matches expected schema."""
        response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-schema-test"
        })

        assert response.status_code == 200
        data = response.json()

        # All required fields present
        required_fields = ["couple_id", "device_id", "role", "existing_devices"]
        for field in required_fields:
            assert field in data, f"Missing field: {field}"

        # Field types correct
        assert isinstance(data["couple_id"], str)
        assert isinstance(data["device_id"], str)
        assert isinstance(data["role"], str)
        assert data["existing_devices"] is None or isinstance(data["existing_devices"], int)

        # Role is valid literal
        assert data["role"] in ["creator", "partner"]


# ============================================================================
# Test 5: Error Handling and Edge Cases
# ============================================================================

class TestErrorHandling:
    """Test error handling and edge cases."""

    def test_malformed_json(self, client):
        """Test that malformed JSON is handled properly."""
        response = client.post(
            "/pair",
            content="not valid json",
            headers={"Content-Type": "application/json"}
        )

        assert response.status_code == 422

    def test_missing_action_field(self, client):
        """Test request without action field."""
        response = client.post("/pair", json={
            "device_id": "device-test"
        })

        assert response.status_code == 422

    def test_null_values(self, client):
        """Test handling of null values."""
        response = client.post("/pair", json={
            "action": None,
            "device_id": "device-test"
        })

        assert response.status_code == 422

    def test_case_sensitive_action(self, client):
        """Test that action field is case-sensitive."""
        response = client.post("/pair", json={
            "action": "CREATE",  # Should be lowercase "create"
            "device_id": "device-test"
        })

        # Should fail validation (only "create" and "join" are valid)
        assert response.status_code == 422


# ============================================================================
# Test 6: Integration Tests
# ============================================================================

class TestPairingIntegration:
    """Test complete pairing workflows."""

    def test_complete_pairing_workflow(self, client):
        """Test the complete pairing and location sharing workflow."""
        # Step 1: Device 1 creates couple
        create_response = client.post("/pair", json={
            "action": "create",
            "device_id": "device-001"
        })
        assert create_response.status_code == 200
        couple_id = create_response.json()["couple_id"]
        token1 = create_response.json()["auth_token"]

        # Step 2: Device 1 updates location
        update1_response = client.post("/updateLocation", json={
            "couple_id": couple_id,
            "device_id": "device-001",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "is_sharing": True
        }, headers=auth(token1))
        assert update1_response.status_code == 200

        # Step 3: Device 2 joins couple
        join_response = client.post("/pair", json={
            "action": "join",
            "couple_id": couple_id,
            "device_id": "device-002"
        })
        assert join_response.status_code == 200
        assert join_response.json()["existing_devices"] == 1
        token2 = join_response.json()["auth_token"]

        # Step 4: Device 2 updates location
        update2_response = client.post("/updateLocation", json={
            "couple_id": couple_id,
            "device_id": "device-002",
            "latitude": 37.8044,
            "longitude": -122.2712,
            "is_sharing": True
        }, headers=auth(token2))
        assert update2_response.status_code == 200

        # Step 5: Device 1 gets Device 2's location
        partner1_response = client.get(
            f"/partnerLocation?couple_id={couple_id}&device_id=device-001",
            headers=auth(token1)
        )
        assert partner1_response.status_code == 200
        partner1_data = partner1_response.json()
        assert partner1_data["partner_found"] is True
        assert partner1_data["is_sharing"] is True
        assert partner1_data["latitude"] == 37.8044
        assert partner1_data["longitude"] == -122.2712

        # Step 6: Device 2 gets Device 1's location
        partner2_response = client.get(
            f"/partnerLocation?couple_id={couple_id}&device_id=device-002",
            headers=auth(token2)
        )
        assert partner2_response.status_code == 200
        partner2_data = partner2_response.json()
        assert partner2_data["partner_found"] is True
        assert partner2_data["is_sharing"] is True
        assert partner2_data["latitude"] == 37.7749
        assert partner2_data["longitude"] == -122.4194

    def test_multiple_couples_isolation(self, client):
        """Test that multiple couples remain isolated."""
        # Create couple 1
        create1 = client.post("/pair", json={
            "action": "create",
            "device_id": "couple1-device1"
        })
        couple_id_1 = create1.json()["couple_id"]
        token_1 = create1.json()["auth_token"]

        # Create couple 2
        create2 = client.post("/pair", json={
            "action": "create",
            "device_id": "couple2-device1"
        })
        couple_id_2 = create2.json()["couple_id"]
        token_2 = create2.json()["auth_token"]

        # Add locations for couple 1
        client.post("/updateLocation", json={
            "couple_id": couple_id_1,
            "device_id": "couple1-device1",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "is_sharing": True
        }, headers=auth(token_1))

        # Add locations for couple 2
        client.post("/updateLocation", json={
            "couple_id": couple_id_2,
            "device_id": "couple2-device1",
            "latitude": 40.7128,
            "longitude": -74.0060,
            "is_sharing": True
        }, headers=auth(token_2))

        # Couple 1 should not see couple 2's location
        partner_response = client.get(
            f"/partnerLocation?couple_id={couple_id_1}&device_id=couple1-device1",
            headers=auth(token_1)
        )
        assert partner_response.status_code == 200
        data = partner_response.json()
        assert data["partner_found"] is False  # No partner yet in couple 1

        # Device cannot join wrong couple
        join_wrong = client.post("/pair", json={
            "action": "join",
            "couple_id": "ABCDEFGH",
            "device_id": "malicious-device"
        })
        assert join_wrong.status_code == 404


# ============================================================================
# Test 7: CRUD Function Tests
# ============================================================================

class TestCRUDFunctions:
    """Test CRUD helper functions directly."""

    def test_count_devices_for_couple(self, client):
        """Test counting devices for a couple."""
        db = TestingSessionLocal()
        try:
            # Create couple (now stores a DeviceLocation immediately)
            response = client.post("/pair", json={
                "action": "create",
                "device_id": "device-count-1"
            })
            couple_id = response.json()["couple_id"]
            token = response.json()["auth_token"]

            # After CREATE, 1 device record exists (creator placeholder)
            count = crud.count_devices_for_couple(db, couple_id)
            assert count == 1, f"Expected 1 device after CREATE, found {count}"

            # Update the creator's location (upserts existing record)
            client.post("/updateLocation", json={
                "couple_id": couple_id,
                "device_id": "device-count-1",
                "latitude": 37.7749,
                "longitude": -122.4194,
                "is_sharing": True
            }, headers=auth(token))

            count = crud.count_devices_for_couple(db, couple_id)
            assert count == 1, f"Expected 1 device after updateLocation, found {count}"

            # Join as second device
            client.post("/pair", json={
                "action": "join",
                "couple_id": couple_id,
                "device_id": "device-count-2"
            })

            count = crud.count_devices_for_couple(db, couple_id)
            assert count == 2, f"Expected 2 devices after JOIN, found {count}"
        finally:
            db.close()

    def test_couple_exists(self, client):
        """Test couple existence check."""
        db = TestingSessionLocal()
        try:
            # Non-existent couple
            exists = crud.couple_exists(db, "ABCDEFGH")
            assert exists is False

            # Create couple (now stores DeviceLocation immediately)
            response = client.post("/pair", json={
                "action": "create",
                "device_id": "device-exists"
            })
            couple_id = response.json()["couple_id"]

            # Now exists immediately (CREATE stores a record)
            exists = crud.couple_exists(db, couple_id)
            assert exists is True
        finally:
            db.close()

    def test_get_all_devices_for_couple(self, client):
        """Test retrieving all devices for a couple."""
        db = TestingSessionLocal()
        try:
            # Create couple
            response = client.post("/pair", json={
                "action": "create",
                "device_id": "device-all-1"
            })
            couple_id = response.json()["couple_id"]
            token = response.json()["auth_token"]

            # Update creator's location
            client.post("/updateLocation", json={
                "couple_id": couple_id,
                "device_id": "device-all-1",
                "latitude": 37.7749,
                "longitude": -122.4194,
                "is_sharing": True
            }, headers=auth(token))

            # Join as second device
            client.post("/pair", json={
                "action": "join",
                "couple_id": couple_id,
                "device_id": "device-all-2"
            })

            # Get all devices
            devices = crud.get_all_devices_for_couple(db, couple_id)
            assert len(devices) == 2

            device_ids = [d.device_id for d in devices]
            assert "device-all-1" in device_ids
            assert "device-all-2" in device_ids
        finally:
            db.close()


# ============================================================================
# Test 8: Unpair / DELETE Tests
# ============================================================================

class TestUnpair:
    """Test the DELETE /api/pair/{couple_id} endpoint."""

    def test_unpair_success(self, client):
        """Test successful unpairing."""
        # Create and join
        create_resp = client.post("/pair", json={
            "action": "create",
            "device_id": "device-unpair-1"
        })
        couple_id = create_resp.json()["couple_id"]
        token = create_resp.json()["auth_token"]

        client.post("/pair", json={
            "action": "join",
            "couple_id": couple_id,
            "device_id": "device-unpair-2"
        })

        # Unpair
        delete_resp = client.delete(
            f"/api/pair/{couple_id}?device_id=device-unpair-1",
            headers=auth(token)
        )
        assert delete_resp.status_code == 200
        data = delete_resp.json()
        assert data["success"] is True
        assert data["devices_removed"] == 2

    def test_unpair_requires_token(self, client):
        """Unpairing without the device's token is rejected."""
        create_resp = client.post("/pair", json={
            "action": "create",
            "device_id": "device-unpair-noauth"
        })
        couple_id = create_resp.json()["couple_id"]

        response = client.delete(
            f"/api/pair/{couple_id}?device_id=device-unpair-noauth"
        )
        assert response.status_code == 401

    def test_unpair_nonexistent_couple(self, client):
        """Test unpairing a couple that doesn't exist."""
        response = client.delete(
            "/api/pair/ABCDEFGH?device_id=device-test"
        )
        assert response.status_code == 404

    def test_unpair_wrong_device(self, client):
        """Test unpairing with a device that's not part of the couple."""
        create_resp = client.post("/pair", json={
            "action": "create",
            "device_id": "device-owner"
        })
        couple_id = create_resp.json()["couple_id"]

        # Unknown device is indistinguishable from an unknown couple: 404
        response = client.delete(
            f"/api/pair/{couple_id}?device_id=device-intruder"
        )
        assert response.status_code == 404


