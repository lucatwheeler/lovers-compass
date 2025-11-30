# Lover's Compass Backend - Quick Start Guide

## 🚀 Getting Started (5 Minutes)

### 1. Install Dependencies
```bash
cd "/Users/ltw/Desktop/lover's compass"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Run the Server
```bash
uvicorn app.main:app --reload
```

Server will start at: `http://localhost:8000`

### 3. Test It Works
Open your browser to:
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

Or use curl:
```bash
curl http://localhost:8000/health
# Expected: {"status":"ok"}
```

---

## 📁 Project Structure

```
lover's compass/
├── app/
│   ├── main.py              # FastAPI app + health endpoint
│   ├── config.py            # Environment configuration
│   ├── database.py          # Database setup
│   ├── models.py            # DeviceLocation model
│   └── logging_config.py    # Logging setup
├── requirements.txt         # Python dependencies
├── .env.example            # Example environment variables
└── README.md               # Full documentation
```

---

## 🔧 Configuration

### Option 1: Use Defaults (Easiest)
No configuration needed! Defaults work for local development.

### Option 2: Custom Configuration
Create a `.env` file:
```bash
cp .env.example .env
```

Edit `.env`:
```bash
ENV=development
DATABASE_URL=sqlite:///./lovers_compass.db
ALLOWED_ORIGINS=["http://localhost:3000"]
```

---

## 🧪 Testing

### Test All Endpoints
```bash
# Health check
curl http://localhost:8000/health

# API information
curl http://localhost:8000/

# OpenAPI schema
curl http://localhost:8000/openapi.json
```

### Check Database
```bash
sqlite3 lovers_compass.db ".schema device_locations"
```

---

## 📊 Available Endpoints (Current Phase)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns `{"status": "ok"}`) |
| `/` | GET | API information and metadata |
| `/docs` | GET | Interactive API documentation (Swagger UI) |
| `/redoc` | GET | Alternative API documentation (ReDoc) |
| `/openapi.json` | GET | OpenAPI schema |

---

## 🔐 Database Schema

```sql
CREATE TABLE device_locations (
    id VARCHAR NOT NULL,              -- Primary key: {couple_id}:{device_id}
    couple_id VARCHAR(8) NOT NULL,    -- 8-character pairing code
    device_id VARCHAR(36) NOT NULL,   -- UUID v4
    latitude FLOAT NOT NULL,          -- Latitude (-90 to 90)
    longitude FLOAT NOT NULL,         -- Longitude (-180 to 180)
    updated_at DATETIME NOT NULL,     -- UTC timestamp
    is_sharing BOOLEAN NOT NULL,      -- Privacy flag
    PRIMARY KEY (id)
)
```

**Indexes:**
- `idx_couple_device`: Unique index on `(couple_id, device_id)`
- `ix_device_locations_couple_id`: Index on `couple_id`

---

## 🛠️ Common Commands

### Development
```bash
# Run with auto-reload (development)
uvicorn app.main:app --reload

# Run on custom port
uvicorn app.main:app --port 8080

# Run with specific host
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Database
```bash
# View database schema
sqlite3 lovers_compass.db ".schema"

# View all tables
sqlite3 lovers_compass.db ".tables"

# Query data (when you have some)
sqlite3 lovers_compass.db "SELECT * FROM device_locations;"
```

### Testing
```bash
# Test health endpoint
curl -s http://localhost:8000/health | python3 -m json.tool

# Test root endpoint
curl -s http://localhost:8000/ | python3 -m json.tool
```

---

## 📝 Next Steps

### Phase 2: Pairing Endpoints (Next)
- [ ] Implement pairing code generation
- [ ] Create `/pair` endpoint for device pairing
- [ ] Add CRUD operations for couples

### Phase 3: Location Endpoints
- [ ] Implement `/updateLocation` endpoint
- [ ] Implement `/partnerLocation` endpoint
- [ ] Add location update logic

### Phase 4: Rate Limiting
- [ ] Install slowapi
- [ ] Configure rate limits
- [ ] Add brute-force protection

### Phase 5: Deployment
- [ ] Configure Railway deployment
- [ ] Set up production environment
- [ ] Update CORS for iOS app

---

## 🚨 Troubleshooting

### Server won't start
```bash
# Check if port is already in use
lsof -i :8000

# Kill existing process
kill -9 <PID>

# Try different port
uvicorn app.main:app --port 8080
```

### Import errors
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Database errors
```bash
# Delete database and restart (WARNING: loses all data)
rm lovers_compass.db
uvicorn app.main:app --reload
```

### CORS errors from iOS app
Edit `.env`:
```bash
ALLOWED_ORIGINS=["http://localhost:8000","https://yourapp.com"]
```

---

## 📚 Documentation

- **Full Implementation Details**: `IMPLEMENTATION_REPORT.md`
- **Comprehensive Guide**: `README.md`
- **API Documentation**: http://localhost:8000/docs (when running)

---

## 💡 Tips

1. **Use the interactive docs**: http://localhost:8000/docs lets you test endpoints in your browser
2. **Check the logs**: Server logs show all requests and SQL queries (in development)
3. **Database is SQLite**: Easy to inspect with any SQLite viewer
4. **Auto-reload is enabled**: Code changes automatically restart the server
5. **Type safety everywhere**: Pydantic catches configuration errors early

---

## 🎯 What's Working Now

✅ FastAPI server with auto-documentation
✅ Health check endpoint for monitoring
✅ Database initialization with proper schema
✅ Environment-based configuration
✅ CORS configured for iOS app
✅ Comprehensive logging
✅ Privacy-conscious architecture

---

## 📞 Support

For questions or issues:
1. Check `IMPLEMENTATION_REPORT.md` for detailed information
2. Review `README.md` for comprehensive documentation
3. Check server logs for error messages
4. Verify `.env` configuration (if using custom settings)

---

**Version**: 0.1.0 (Phase 1 of 8)
**Last Updated**: November 29, 2025
**Status**: ✅ Ready for Phase 2
