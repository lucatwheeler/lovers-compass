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

## Deployment

### Local Development (Quick Start)

```bash
# 1. Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run development server
uvicorn app.main:app --reload

# 4. Access the API
# Swagger UI: http://127.0.0.1:8000/docs
# Health check: http://127.0.0.1:8000/health
```

### Production Deployment (Railway)

#### Prerequisites
- GitHub repository with this codebase
- [Railway account](https://railway.app/) (free tier works)
- Python 3.11+ for local development

#### Step 1: Prepare Repository

Ensure your repo contains:
- ✅ `Procfile` (defines web process)
- ✅ `requirements.txt` (Python dependencies)
- ✅ `runtime.txt` (Python version: 3.11.7)
- ✅ `.env.example` (template for environment variables)

#### Step 2: Deploy to Railway

1. **Push code to GitHub**
   ```bash
   git add .
   git commit -m "Prepare for Railway deployment"
   git push origin main
   ```

2. **Create Railway project**
   - Log in to [Railway](https://railway.app/)
   - Click "New Project" → "Deploy from GitHub repo"
   - Select your `lover's-compass-backend` repository
   - Railway auto-detects Python via `runtime.txt` and `requirements.txt`

3. **Configure environment variables** (Railway dashboard → Variables tab)

   **Required:**
   ```
   ENV=production
   ```

   **Optional (for PostgreSQL):**
   ```
   DATABASE_URL=postgresql://user:pass@host:5432/dbname
   ```

   *Note: If `DATABASE_URL` is not set, the app uses SQLite (stored on Railway's ephemeral filesystem, acceptable for 2-person use cases). For persistence, add Railway Postgres plugin.*

   **Optional (CORS for iOS app):**
   ```
   ALLOWED_ORIGINS=["https://your-ios-app-domain.com"]
   ```

4. **Deploy**
   - Railway automatically builds and deploys on every push to `main`
   - First deployment takes ~2-3 minutes
   - Railway provides a public URL: `https://your-app.up.railway.app`

#### Step 3: Verify Deployment

1. **Health check**
   ```bash
   curl https://your-app.up.railway.app/health
   # Expected: {"status":"ok"}
   ```

2. **API documentation**
   - Visit `https://your-app.up.railway.app/docs`
   - Interactive OpenAPI (Swagger) UI should load

3. **Test pairing endpoint**
   ```bash
   curl -X POST https://your-app.up.railway.app/pair \
     -H "Content-Type: application/json" \
     -d '{"action":"create","device_id":"test-001"}'
   # Expected: {"couple_id":"XXXXXXXX","device_id":"test-001","role":"creator",...}
   ```

#### Production Features

✅ **Security**
- HTTPS enabled automatically by Railway
- OWASP security headers active (X-Frame-Options, X-Content-Type-Options, etc.)
- HSTS enforced in production (app/main.py:144)

✅ **Rate Limiting**
- IP-based: 5 req/min on `/pair`, 60 req/min on `/updateLocation`, 120 req/min on `/partnerLocation`
- Device-based: 6 req/min on `/updateLocation`, 12 req/min on `/partnerLocation`
- 429 responses when limits exceeded

✅ **Privacy**
- No location history stored (only latest point)
- Coordinates never appear in logs
- `is_sharing=false` stops coordinate disclosure

#### Database Options

**Option 1: SQLite (Default - No setup required)**
- Suitable for: 2-person couples app, development, prototyping
- Limitations: Ephemeral storage (data lost on Railway restart)
- Cost: Free

**Option 2: PostgreSQL (Recommended for production)**
1. Add Railway Postgres plugin to your project
2. Railway auto-creates `DATABASE_URL` environment variable
3. App automatically switches to PostgreSQL (no code changes)
4. Persistent storage across deployments

#### Future: Database Migrations

When you need schema changes with PostgreSQL:
1. Install Alembic: `pip install alembic`
2. Initialize migrations: `alembic init alembic`
3. Generate migration: `alembic revision --autogenerate -m "description"`
4. Apply migration: `alembic upgrade head`

*For now, the app uses `Base.metadata.create_all()` which works for initial deployment.*

#### Monitoring & Logs

**View logs in Railway:**
- Railway dashboard → Deployments tab → Click active deployment
- Real-time logs show requests, errors, rate limiting events

**Key log patterns to monitor:**
- `Pairing code created:` - New couple registrations
- `Location updated successfully:` - Location sync activity
- `Rate limit exceeded:` - Potential abuse attempts

#### Troubleshooting

**Build fails:**
- Verify `runtime.txt` matches installed Python version
- Check `requirements.txt` for typos or version conflicts

**App crashes:**
- Check Railway logs for startup errors
- Verify `ENV=production` is set
- Ensure `PORT` environment variable is available (Railway provides this automatically)

**Database connection issues:**
- SQLite: Check file permissions (should auto-create)
- PostgreSQL: Verify `DATABASE_URL` format and credentials

#### Cost Estimate

**Railway Free Tier:**
- $5 credit/month (no credit card required)
- Sufficient for ~500 hours/month of low-traffic apps
- Sleep after inactivity (wakes on request)

**Hobby Plan ($5/month):**
- No sleep
- Custom domains
- Priority support

*For a 2-person couples app, free tier is typically sufficient.*

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

## Development Roadmap

The following phases have been completed:

1. ~~Device pairing endpoints (`/pair`)~~ ✅ Completed (Phase 3)
2. ~~Location update endpoint (`/updateLocation`)~~ ✅ Completed (Phase 2)
3. ~~Partner location retrieval (`/partnerLocation`)~~ ✅ Completed (Phase 2)
4. ~~Rate limiting and security enhancements~~ ✅ Completed (Phase 4)
5. ~~Production deployment configuration~~ ✅ Completed (Phase 5)

**Status**: Production-ready backend with Railway deployment support

## License

Personal project - Not for public distribution
