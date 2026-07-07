# Lover's Compass API - Usage Examples

**Version**: 1.0.0
**Base URL**: `http://localhost:8000` (development) / `https://lovers-compass.onrender.com` (production)

---

## Overview

This document provides practical examples for using the Lover's Compass API endpoints.
All examples use `curl` for demonstration, but any HTTP client will work.

---

## What's New in 1.0.0

### Device token auth (required)

`POST /pair` (both `create` and `join`) now returns an `auth_token` for the
device. It is returned **exactly once** — store it securely (iOS Keychain /
localStorage). Every subsequent request must send it:

```
Authorization: Bearer <auth_token>
```

Applies to: `POST /updateLocation`, `GET /partnerLocation`, `POST /poke`,
`GET /pokes`, `DELETE /api/pair/{couple_id}`. Requests without a valid token
get `401`; unknown couple/device combinations get `404`.

Devices paired before 1.0.0 have no token on file and are still accepted
(legacy grace). They can claim a token once via:

```bash
curl -X POST $BASE/auth/token \
  -H "Content-Type: application/json" \
  -d '{"couple_id": "AB12CD34", "device_id": "<device uuid>"}'
# -> {"auth_token": "..."}   (409 if the device already has one)
```

### Poke messages

`POST /poke` accepts an optional `message` (max 240 chars):

```json
{"couple_id": "AB12CD34", "device_id": "...", "message": "miss you 🥺"}
```

`GET /pokes` now returns the messages (oldest first) alongside the count:

```json
{"pokes": 2, "latest_at": "...", "messages": [{"message": "miss you 🥺", "created_at": "..."}, {"message": null, "created_at": "..."}]}
```

### Invite links

`GET /join/{code}` serves an HTML landing page for sharing invites over
https. It deep-links into the iOS app (`loverscompass://join/CODE`), falls
back to the App Store (`APP_STORE_URL` env var) or the web app (`/?code=CODE`).
The page renders for any well-formed code without revealing whether it exists.

`GET /.well-known/apple-app-site-association` enables iOS Universal Links
once the `APPLE_TEAM_ID` env var is set (404 until then).

---

## Endpoints

### 1. Pairing

**Endpoint**: `POST /pair`

**Purpose**: Create a new couple (generate pairing code) or join an existing couple

#### Action: Create (Generate Pairing Code)

**Request Body**:
```json
{
  "action": "create",
  "device_id": "DEVICE_A_UUID"
}
```

**Example**:
```bash
curl -X POST http://localhost:8000/pair \
  -H "Content-Type: application/json" \
  -d '{
    "action": "create",
    "device_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

**Response**:
```json
{
  "couple_id": "AB12CD34",
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "role": "creator",
  "existing_devices": null
}
```

#### Action: Join (Use Pairing Code)

**Request Body**:
```json
{
  "action": "join",
  "couple_id": "AB12CD34",
  "device_id": "DEVICE_B_UUID"
}
```

**Example**:
```bash
curl -X POST http://localhost:8000/pair \
  -H "Content-Type: application/json" \
  -d '{
    "action": "join",
    "couple_id": "AB12CD34",
    "device_id": "660f9511-f39c-52e5-b827-557766551111"
  }'
```

**Response** (successful join):
```json
{
  "couple_id": "AB12CD34",
  "device_id": "660f9511-f39c-52e5-b827-557766551111",
  "role": "partner",
  "existing_devices": 1
}
```

**Error Response** (pairing code not found):
```json
{
  "detail": "Pairing code not found"
}
```
HTTP Status: 404

**Error Response** (couple already full):
```json
{
  "detail": "This couple is already paired with 2 devices"
}
```
HTTP Status: 409

---

### 2. Health Check

**Endpoint**: `GET /health`

**Purpose**: Verify the API is running

**Example**:
```bash
curl http://localhost:8000/health
```

**Response**:
```json
{
  "status": "ok"
}
```

---

### 3. Update Location

**Endpoint**: `POST /updateLocation`

**Purpose**: Update or create a device's current location

**Request Body**:
```json
{
  "couple_id": "ABC123XY",
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "is_sharing": true
}
```

**Field Descriptions**:
- `couple_id` (string, required): Unique identifier for the couple (pairing code)
- `device_id` (string, required): Unique identifier for this device (UUID)
- `latitude` (float, required): Latitude coordinate (-90 to 90)
- `longitude` (float, required): Longitude coordinate (-180 to 180)
- `is_sharing` (boolean, optional): Whether sharing location (default: true)

**Example - Device 1**:
```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "ABC123XY",
    "device_id": "device-001",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "is_sharing": true
  }'
```

**Response**:
```json
{
  "success": true,
  "updated_at": "2025-11-29T12:34:56.789000Z"
}
```

**Example - Device 2**:
```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "ABC123XY",
    "device_id": "device-002",
    "latitude": 37.8044,
    "longitude": -122.2712,
    "is_sharing": true
  }'
```

**Example - Pause Sharing**:
```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "ABC123XY",
    "device_id": "device-001",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "is_sharing": false
  }'
```

---

### 4. Get Partner Location

**Endpoint**: `GET /partnerLocation`

**Purpose**: Retrieve the partner's current location

**Query Parameters**:
- `couple_id` (string, required): Unique identifier for the couple
- `device_id` (string, required): Your device ID (to exclude from results)

**Example - No Partner Yet**:
```bash
curl "http://localhost:8000/partnerLocation?couple_id=ABC123XY&device_id=device-001"
```

**Response** (no partner):
```json
{
  "partner_found": false,
  "is_sharing": null,
  "latitude": null,
  "longitude": null,
  "updated_at": null,
  "staleness_seconds": null
}
```

**Example - Partner Exists and Sharing**:
```bash
curl "http://localhost:8000/partnerLocation?couple_id=ABC123XY&device_id=device-001"
```

**Response** (partner sharing):
```json
{
  "partner_found": true,
  "is_sharing": true,
  "latitude": 37.8044,
  "longitude": -122.2712,
  "updated_at": "2025-11-29T12:32:56.789000Z",
  "staleness_seconds": 45
}
```

**Example - Partner Not Sharing**:
```bash
curl "http://localhost:8000/partnerLocation?couple_id=ABC123XY&device_id=device-002"
```

**Response** (partner paused):
```json
{
  "partner_found": true,
  "is_sharing": false,
  "latitude": null,
  "longitude": null,
  "updated_at": null,
  "staleness_seconds": 120
}
```

---

## Complete Workflow Example

### Scenario: Complete Pairing and Location Sharing

**Step 1**: Device 1 creates a couple (generates pairing code)
```bash
curl -X POST http://localhost:8000/pair \
  -H "Content-Type: application/json" \
  -d '{
    "action": "create",
    "device_id": "device-001"
  }'
```

**Response**:
```json
{
  "couple_id": "AB12CD34",
  "device_id": "device-001",
  "role": "creator",
  "existing_devices": null
}
```

**Step 2**: Device 2 joins using the pairing code
```bash
curl -X POST http://localhost:8000/pair \
  -H "Content-Type: application/json" \
  -d '{
    "action": "join",
    "couple_id": "AB12CD34",
    "device_id": "device-002"
  }'
```

**Response**:
```json
{
  "couple_id": "AB12CD34",
  "device_id": "device-002",
  "role": "partner",
  "existing_devices": 1
}
```

**Step 3**: Device 1 updates location
```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "AB12CD34",
    "device_id": "device-001",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "is_sharing": true
  }'
```

**Step 4**: Device 2 updates location
```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "AB12CD34",
    "device_id": "device-002",
    "latitude": 37.8044,
    "longitude": -122.2712,
    "is_sharing": true
  }'
```

**Step 5**: Device 1 queries partner location (gets Device 2's location)
```bash
curl "http://localhost:8000/partnerLocation?couple_id=AB12CD34&device_id=device-001"
```

**Response**:
```json
{
  "partner_found": true,
  "is_sharing": true,
  "latitude": 37.8044,
  "longitude": -122.2712,
  "updated_at": "2025-11-29T12:35:00.000000Z",
  "staleness_seconds": 10
}
```

**Step 6**: Device 2 queries partner location (gets Device 1's location)
```bash
curl "http://localhost:8000/partnerLocation?couple_id=AB12CD34&device_id=device-002"
```

**Response**:
```json
{
  "partner_found": true,
  "is_sharing": true,
  "latitude": 37.7749,
  "longitude": -122.4194,
  "updated_at": "2025-11-29T12:34:56.789000Z",
  "staleness_seconds": 14
}
```

---

## Testing Script

Save this as `test_api.sh` for quick testing:

```bash
#!/bin/bash

BASE_URL="http://localhost:8000"
COUPLE_ID="TEST123"
DEVICE_1="device-001"
DEVICE_2="device-002"

echo "=== Testing Lover's Compass API ==="
echo ""

echo "1. Health Check"
curl -s $BASE_URL/health | jq
echo ""

echo "2. Update Device 1 Location (San Francisco)"
curl -s -X POST $BASE_URL/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "'$COUPLE_ID'",
    "device_id": "'$DEVICE_1'",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "is_sharing": true
  }' | jq
echo ""

echo "3. Update Device 2 Location (Oakland)"
curl -s -X POST $BASE_URL/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "'$COUPLE_ID'",
    "device_id": "'$DEVICE_2'",
    "latitude": 37.8044,
    "longitude": -122.2712,
    "is_sharing": true
  }' | jq
echo ""

echo "4. Device 1 Gets Partner Location (should see Device 2)"
curl -s "$BASE_URL/partnerLocation?couple_id=$COUPLE_ID&device_id=$DEVICE_1" | jq
echo ""

echo "5. Device 2 Gets Partner Location (should see Device 1)"
curl -s "$BASE_URL/partnerLocation?couple_id=$COUPLE_ID&device_id=$DEVICE_2" | jq
echo ""

echo "6. Device 1 Pauses Sharing"
curl -s -X POST $BASE_URL/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "'$COUPLE_ID'",
    "device_id": "'$DEVICE_1'",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "is_sharing": false
  }' | jq
echo ""

echo "7. Device 2 Gets Partner Location (should see is_sharing=false)"
curl -s "$BASE_URL/partnerLocation?couple_id=$COUPLE_ID&device_id=$DEVICE_2" | jq
echo ""

echo "=== Testing Complete ==="
```

**Usage**:
```bash
chmod +x test_api.sh
./test_api.sh
```

---

## Error Responses

### Validation Error (400)
Invalid request data (e.g., latitude out of range):

```bash
curl -X POST http://localhost:8000/updateLocation \
  -H "Content-Type: application/json" \
  -d '{
    "couple_id": "ABC123XY",
    "device_id": "device-001",
    "latitude": 200.0,
    "longitude": -122.4194,
    "is_sharing": true
  }'
```

**Response**:
```json
{
  "detail": [
    {
      "type": "less_than_equal",
      "loc": ["body", "latitude"],
      "msg": "Input should be less than or equal to 90",
      "input": 200.0
    }
  ]
}
```

### Database Error (500)
Server-side error:

**Response**:
```json
{
  "detail": "Failed to update location due to database error"
}
```

---

## Privacy Notes

1. **No Location History**: Only the most recent location per device is stored
2. **Coordinates Protected**: Lat/lon values are never logged in server logs
3. **Sharing Control**: `is_sharing=false` prevents coordinates from being returned
4. **Minimal Data**: Only couple_id, device_id, coordinates, timestamp, and sharing flag are stored

---

## Next Steps

- **Phase 3**: Pairing code generation and validation
- **Phase 4**: Rate limiting to prevent API abuse
- **Phase 5**: Production deployment to Railway

For more details, see the main README.md or visit `/docs` for interactive API documentation.
