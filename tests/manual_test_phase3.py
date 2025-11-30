"""
Manual Integration Tests for Phase 3: Pairing System

Tests the live running server at http://localhost:8000
Run server first with: uvicorn app.main:app --host 127.0.0.1 --port 8000
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

# Test results tracking
results = {
    "passed": [],
    "failed": [],
    "total": 0
}


def test(name, condition, details=""):
    """Track test result."""
    results["total"] += 1
    if condition:
        results["passed"].append(name)
        print(f"✅ PASS: {name}")
        if details:
            print(f"   {details}")
    else:
        results["failed"].append(name)
        print(f"❌ FAIL: {name}")
        if details:
            print(f"   {details}")


def print_summary():
    """Print test summary."""
    print("\n" + "="*80)
    print(f"TEST SUMMARY: {len(results['passed'])}/{results['total']} PASSED")
    print("="*80)

    if results["failed"]:
        print(f"\n❌ FAILED TESTS ({len(results['failed'])}):")
        for name in results["failed"]:
            print(f"   - {name}")

    pass_rate = (len(results["passed"]) / results["total"]) * 100 if results["total"] > 0 else 0
    print(f"\nPASS RATE: {pass_rate:.1f}%")


print("="*80)
print("PHASE 3 PAIRING SYSTEM - MANUAL INTEGRATION TESTS")
print("="*80)

# ============================================================================
# Test 1: Health Check
# ============================================================================
print("\n[1] Health Check")
try:
    response = requests.get(f"{BASE_URL}/health", timeout=5)
    test("Health check returns 200", response.status_code == 200)
    test("Health check returns correct status", response.json().get("status") == "ok")
except Exception as e:
    test("Health check", False, str(e))

# ============================================================================
# Test 2: POST /pair CREATE Action
# ============================================================================
print("\n[2] CREATE Action Tests")

# Test 2.1: Successful creation
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "test-device-create-1"
    }, timeout=5)
    test("CREATE returns 200", response.status_code == 200)

    data = response.json()
    couple_id_1 = data.get("couple_id")

    test("CREATE returns couple_id", "couple_id" in data and len(couple_id_1) == 8)
    test("CREATE returns correct device_id", data.get("device_id") == "test-device-create-1")
    test("CREATE returns role=creator", data.get("role") == "creator")
    test("CREATE returns existing_devices=null", data.get("existing_devices") is None)
except Exception as e:
    test("CREATE action", False, str(e))
    couple_id_1 = None

# Test 2.2: Multiple creations produce unique codes
try:
    response2 = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "test-device-create-2"
    }, timeout=5)
    couple_id_2 = response2.json().get("couple_id")

    test("Multiple CREATEs produce unique codes", couple_id_1 != couple_id_2)
except Exception as e:
    test("Multiple CREATE uniqueness", False, str(e))

# Test 2.3: Code format validation
try:
    # Verify format: 8 chars, uppercase, alphanumeric, no ambiguous chars
    allowed = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    is_valid_format = (
        len(couple_id_1) == 8 and
        couple_id_1.isupper() and
        couple_id_1.isalnum() and
        all(c in allowed for c in couple_id_1)
    )
    test("Pairing code format valid", is_valid_format,
         f"Code: {couple_id_1}, Length: {len(couple_id_1)}")
except Exception as e:
    test("Code format validation", False, str(e))

# ============================================================================
# Test 3: POST /pair JOIN Action
# ============================================================================
print("\n[3] JOIN Action Tests")

# Test 3.1: Join non-existent code (404)
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": "NOTEXIST",
        "device_id": "test-device-join-1"
    }, timeout=5)
    test("JOIN non-existent code returns 404", response.status_code == 404)
    test("404 error message correct", "Pairing code not found" in response.json().get("detail", ""))
except Exception as e:
    test("JOIN non-existent code", False, str(e))

# Test 3.2: JOIN without couple_id (400)
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "device_id": "test-device-join-2"
    }, timeout=5)
    test("JOIN without couple_id returns 400", response.status_code == 400)
    test("400 error message correct", "couple_id is required" in response.json().get("detail", ""))
except Exception as e:
    test("JOIN without couple_id", False, str(e))

# Test 3.3: Successful JOIN workflow
try:
    # Create couple
    create_resp = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "device-join-creator"
    }, timeout=5)
    join_couple_id = create_resp.json()["couple_id"]

    # Add creator's location
    requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": join_couple_id,
        "device_id": "device-join-creator",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "is_sharing": True
    }, timeout=5)

    # Join as partner
    join_resp = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": join_couple_id,
        "device_id": "device-join-partner"
    }, timeout=5)

    test("Successful JOIN returns 200", join_resp.status_code == 200)

    join_data = join_resp.json()
    test("JOIN returns correct couple_id", join_data.get("couple_id") == join_couple_id)
    test("JOIN returns role=partner", join_data.get("role") == "partner")
    test("JOIN returns existing_devices=1", join_data.get("existing_devices") == 1)

except Exception as e:
    test("Successful JOIN workflow", False, str(e))

# Test 3.4: JOIN full couple (409)
try:
    # Add partner's location
    requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": join_couple_id,
        "device_id": "device-join-partner",
        "latitude": 37.8044,
        "longitude": -122.2712,
        "is_sharing": True
    }, timeout=5)

    # Try to join as third device
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": join_couple_id,
        "device_id": "device-join-third"
    }, timeout=5)

    test("JOIN full couple returns 409", response.status_code == 409)
    test("409 error message correct", "already paired with 2 devices" in response.json().get("detail", ""))
except Exception as e:
    test("JOIN full couple", False, str(e))

# ============================================================================
# Test 4: Schema Validation
# ============================================================================
print("\n[4] Schema Validation Tests")

# Test 4.1: Invalid action
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "invalid",
        "device_id": "test-device"
    }, timeout=5)
    test("Invalid action returns 422", response.status_code == 422)
except Exception as e:
    test("Invalid action validation", False, str(e))

# Test 4.2: Missing device_id
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "create"
    }, timeout=5)
    test("Missing device_id returns 422", response.status_code == 422)
except Exception as e:
    test("Missing device_id validation", False, str(e))

# Test 4.3: Empty device_id
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": ""
    }, timeout=5)
    test("Empty device_id returns 422", response.status_code == 422)
except Exception as e:
    test("Empty device_id validation", False, str(e))

# Test 4.4: Device_id too long
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "x" * 101
    }, timeout=5)
    test("Device_id >100 chars returns 422", response.status_code == 422)
except Exception as e:
    test("Device_id length validation", False, str(e))

# Test 4.5: Couple_id wrong length
try:
    response = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": "SHORT",
        "device_id": "test-device"
    }, timeout=5)
    test("Couple_id <8 chars returns 422", response.status_code == 422)
except Exception as e:
    test("Couple_id length validation", False, str(e))

# ============================================================================
# Test 5: Complete Pairing Workflow
# ============================================================================
print("\n[5] Complete Pairing Workflow")

try:
    # Step 1: Device 1 creates couple
    create = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "workflow-device-1"
    }, timeout=5)
    workflow_couple_id = create.json()["couple_id"]
    test("Workflow: CREATE succeeds", create.status_code == 200)

    # Step 2: Device 1 updates location
    update1 = requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": workflow_couple_id,
        "device_id": "workflow-device-1",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "is_sharing": True
    }, timeout=5)
    test("Workflow: Device 1 location update", update1.status_code == 200)

    # Step 3: Device 1 checks partner (should be none)
    partner1_before = requests.get(
        f"{BASE_URL}/partnerLocation?couple_id={workflow_couple_id}&device_id=workflow-device-1",
        timeout=5
    )
    test("Workflow: No partner initially",
         partner1_before.json().get("partner_found") == False)

    # Step 4: Device 2 joins
    join = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": workflow_couple_id,
        "device_id": "workflow-device-2"
    }, timeout=5)
    test("Workflow: JOIN succeeds", join.status_code == 200)
    test("Workflow: JOIN shows existing_devices=1",
         join.json().get("existing_devices") == 1)

    # Step 5: Device 2 updates location
    update2 = requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": workflow_couple_id,
        "device_id": "workflow-device-2",
        "latitude": 37.8044,
        "longitude": -122.2712,
        "is_sharing": True
    }, timeout=5)
    test("Workflow: Device 2 location update", update2.status_code == 200)

    # Step 6: Device 1 gets Device 2's location
    partner1 = requests.get(
        f"{BASE_URL}/partnerLocation?couple_id={workflow_couple_id}&device_id=workflow-device-1",
        timeout=5
    )
    partner1_data = partner1.json()
    test("Workflow: Device 1 sees partner", partner1_data.get("partner_found") == True)
    test("Workflow: Device 1 sees partner sharing", partner1_data.get("is_sharing") == True)
    test("Workflow: Device 1 gets correct coordinates",
         partner1_data.get("latitude") == 37.8044 and
         partner1_data.get("longitude") == -122.2712)

    # Step 7: Device 2 gets Device 1's location
    partner2 = requests.get(
        f"{BASE_URL}/partnerLocation?couple_id={workflow_couple_id}&device_id=workflow-device-2",
        timeout=5
    )
    partner2_data = partner2.json()
    test("Workflow: Device 2 sees partner", partner2_data.get("partner_found") == True)
    test("Workflow: Device 2 gets correct coordinates",
         partner2_data.get("latitude") == 37.7749 and
         partner2_data.get("longitude") == -122.4194)

except Exception as e:
    test("Complete workflow", False, str(e))

# ============================================================================
# Test 6: Couple Isolation
# ============================================================================
print("\n[6] Multiple Couples Isolation")

try:
    # Create couple A
    createA = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "coupleA-device1"
    }, timeout=5)
    couple_id_A = createA.json()["couple_id"]

    # Create couple B
    createB = requests.post(f"{BASE_URL}/pair", json={
        "action": "create",
        "device_id": "coupleB-device1"
    }, timeout=5)
    couple_id_B = createB.json()["couple_id"]

    test("Isolation: Different couple_ids", couple_id_A != couple_id_B)

    # Add locations for both couples
    requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": couple_id_A,
        "device_id": "coupleA-device1",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "is_sharing": True
    }, timeout=5)

    requests.post(f"{BASE_URL}/updateLocation", json={
        "couple_id": couple_id_B,
        "device_id": "coupleB-device1",
        "latitude": 40.7128,
        "longitude": -74.0060,
        "is_sharing": True
    }, timeout=5)

    # Couple A should not see couple B's location
    partnerA = requests.get(
        f"{BASE_URL}/partnerLocation?couple_id={couple_id_A}&device_id=coupleA-device1",
        timeout=5
    )
    test("Isolation: Couple A doesn't see couple B",
         partnerA.json().get("partner_found") == False)

    # Cannot join wrong couple
    wrongJoin = requests.post(f"{BASE_URL}/pair", json={
        "action": "join",
        "couple_id": "WRONGCOD",
        "device_id": "malicious-device"
    }, timeout=5)
    test("Isolation: Cannot join non-existent couple", wrongJoin.status_code == 404)

except Exception as e:
    test("Couple isolation", False, str(e))

# ============================================================================
# Print Summary
# ============================================================================
print_summary()

# Exit with appropriate code
exit_code = 0 if len(results["failed"]) == 0 else 1
exit(exit_code)
