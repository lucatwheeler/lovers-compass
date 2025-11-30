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

## Next Steps

The following features will be implemented in subsequent phases:

1. Device pairing endpoints (`/pair`)
2. Location update endpoint (`/updateLocation`)
3. Partner location retrieval (`/partnerLocation`)
4. Rate limiting and security enhancements
5. Production deployment configuration

## License

Personal project - Not for public distribution
