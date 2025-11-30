# Lover's Compass - Backend

A minimal, production-ready FastAPI backend for the Lover's Compass app.

## Overview

This is the initial backend scaffold for Lover's Compass, a personal location-sharing app for couples. This version includes the foundational structure with database configuration, logging, and health check endpoint.

**Note**: Location-based endpoints will be added in the next implementation phase.

## Features

- ✅ Clean separation of concerns with modular structure
- ✅ Environment-based configuration using Pydantic Settings
- ✅ SQLAlchemy database integration (SQLite by default, easily swappable)
- ✅ CORS configuration for iOS app integration
- ✅ Centralized logging with sensitive data protection
- ✅ Health check endpoint
- ✅ Device pairing system with unique 8-character codes
- ✅ Location sharing with privacy controls
- ✅ Two-tier rate limiting (IP-based and device-based)
- ✅ Enhanced input validation and security hardening

## Setup

### Prerequisites

- Python 3.11+
- pip

### Installation

1. Clone the repository or copy the project files

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. (Optional) Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` to customize your configuration if needed.

## Running the Application

### Development Mode

```bash
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`

### Access the Documentation

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Testing

### Health Check

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "ok"
}
```

## Project Structure

```
lovers-compass-backend/
├── app/
│   ├── __init__.py          # Package initialization
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Environment configuration
│   ├── database.py          # Database connection and session management
│   ├── models.py            # SQLAlchemy models
│   └── logging_config.py    # Logging configuration
├── requirements.txt         # Python dependencies
├── .env.example            # Example environment variables
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Configuration

Configuration is managed through environment variables and can be set in a `.env` file:

- `ENV`: Application environment (development, staging, production)
- `DATABASE_URL`: Database connection string
- `ALLOWED_ORIGINS`: CORS allowed origins (JSON array format)

## Rate Limiting

The API implements two-tier rate limiting to protect against abuse and ensure fair usage:

### IP-Based Rate Limits

Applied to all clients from the same IP address:

- **POST /pair**: 5 requests per minute
  - Prevents brute force attacks on pairing codes
- **POST /updateLocation**: 60 requests per minute (safety net)
  - Allows multiple devices from same network
- **GET /partnerLocation**: 120 requests per minute (safety net)
  - Accommodates frequent location checks

### Device-Based Rate Limits

Applied per unique (couple_id, device_id) combination:

- **POST /updateLocation**: 6 requests per minute (1 every 10 seconds)
  - Aligns with typical location update frequency
- **GET /partnerLocation**: 12 requests per minute (1 every 5 seconds)
  - Supports responsive partner location tracking

### Rate Limit Responses

When a rate limit is exceeded:
- HTTP Status: `429 Too Many Requests`
- Response headers include:
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining in current window
  - `X-RateLimit-Reset`: Timestamp when the limit resets
- Error message: `"Rate limit exceeded. Please try again later."`

**Note**: Rate limits are enforced using a fixed-window strategy with in-memory storage, suitable for single-instance deployments. For production multi-instance deployments, consider upgrading to Redis-based storage.

## Data & Privacy

Lover's Compass is built with privacy as a core principle:

### Location Data Storage

- **No History**: Only the most recent location is stored per device. No historical tracking.
- **Overwrite Pattern**: Each location update replaces the previous one.
- **Privacy Control**: Users can pause location sharing at any time with `is_sharing=false`.
- **Selective Disclosure**: Partner coordinates are only returned when actively sharing.

### Logging Practices

- **Never Logged**: Latitude and longitude coordinates are never written to logs.
- **Logged Information**: Only high-level events (couple_id, device_id, timestamps, success/failure).
- **Debug Mode**: Even in debug mode, coordinates remain protected.
- **Rate Limit Events**: Only IP addresses are logged when rate limits are exceeded.

### Pairing Code Security

- **Cryptographic Generation**: Pairing codes use Python's `secrets` module for secure randomness.
- **No Ambiguous Characters**: Excludes O/0, I/1/l to prevent user confusion.
- **8-Character Length**: 1.1 trillion possible combinations (32^8) make brute forcing impractical.
- **2-Device Limit**: Each couple can only have 2 paired devices maximum.
- **Format Validation**: Strict validation prevents malformed pairing codes.

### Input Validation

All user input is validated before processing:

- **Coordinate Validation**: Latitude (-90 to 90), Longitude (-180 to 180), no NaN or infinity values.
- **Pairing Code Validation**: Uppercase alphanumeric, 8 characters, allowed character set only.
- **SQL Injection Protection**: All database queries use parameterized statements via SQLAlchemy ORM.
- **Schema Validation**: Pydantic schemas automatically validate and reject malformed requests (HTTP 422).

### Data Retention

- **Active Sessions**: Location data exists only while couples are actively using the app.
- **No Analytics**: No user behavior tracking or analytics data collection.
- **No Third Parties**: No data sharing with external services or third parties.

## Next Steps

The following features will be implemented in subsequent phases:

1. ~~Device pairing endpoints (`/pair`)~~ ✅ Completed (Phase 3)
2. ~~Location update endpoint (`/updateLocation`)~~ ✅ Completed (Phase 2)
3. ~~Partner location retrieval (`/partnerLocation`)~~ ✅ Completed (Phase 2)
4. ~~Rate limiting and security enhancements~~ ✅ Completed (Phase 4)
5. Production deployment configuration (Phase 5)

## License

Personal project - Not for public distribution
