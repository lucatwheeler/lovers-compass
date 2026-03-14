# Love Compass

A private location-sharing app for couples. See your partner on a map, a compass heart that always points to them, and poke them to say you're thinking of them.

## Architecture

```
lovers-compass/
├── app/                    # FastAPI backend (Python)
│   ├── main.py             # API endpoints
│   ├── models.py           # SQLAlchemy models
│   ├── schemas.py          # Pydantic request/response schemas
│   ├── crud.py             # Database operations
│   ├── config.py           # Environment configuration
│   ├── database.py         # SQLAlchemy engine/session
│   ├── rate_limit.py       # Two-tier rate limiting
│   └── logging_config.py   # Privacy-aware logging
├── LoveCompass/            # Native iOS app (SwiftUI)
│   ├── LoveCompass.xcodeproj/
│   └── LoveCompass/
│       ├── LoveCompassApp.swift
│       ├── Views/
│       │   ├── PairingView.swift    # Create/join couple flow
│       │   ├── MapView.swift        # Map + compass + poke
│       │   └── SettingsView.swift   # Code display, unpair
│       ├── Models/
│       │   ├── Location.swift       # Location API models
│       │   └── PairInfo.swift       # Pairing + poke models
│       ├── Services/
│       │   ├── APIService.swift     # Backend communication
│       │   ├── LocationManager.swift # CoreLocation wrapper
│       │   └── KeychainService.swift # Secure credential storage
│       └── Resources/
│           ├── Info.plist
│           └── Assets.xcassets/
├── ios-client/             # Legacy PWA-era iOS client (archived)
├── appstore/               # App Store submission materials
│   ├── privacy-policy.md
│   ├── app-store-description.md
│   └── SUBMISSION_CHECKLIST.md
├── requirements.txt        # Python dependencies
├── Procfile                # Railway deployment
└── README.md               # This file
```

## Backend (FastAPI)

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/pair` | Create or join a couple (action: "create" or "join") |
| POST | `/updateLocation` | Send device location to server |
| GET | `/partnerLocation` | Get partner's latest location |
| POST | `/poke` | Send a poke notification to partner |
| GET | `/pokes` | Get unseen pokes for this device |
| DELETE | `/api/pair/{couple_id}` | Unpair and delete all couple data |
| GET | `/health` | Health check |
| GET | `/api` | API info |

### Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

### Production

Deployed on Railway. The Procfile runs uvicorn on the Railway-provided PORT. Set `ENV=production` in the Railway dashboard.

## iOS App (LoveCompass/)

### Requirements

- Xcode 15.2+
- iOS 17.0+ target
- Physical iPhone for full testing (compass requires magnetometer)

### How to Build

```bash
open LoveCompass/LoveCompass.xcodeproj
```

1. Select your development team in Signing & Capabilities
2. Select a physical iPhone or simulator as the run destination
3. Build and run (Cmd+R)

### Features

- **Device pairing:** One partner creates a couple (generates an 8-character code), the other joins with that code
- **Map view:** MapKit map showing both partners' locations with custom markers
- **Compass heart:** A compass indicator that rotates to point toward your partner
- **Distance display:** Shows how far apart you are in meters or kilometers
- **Poke:** Tap a button to send a notification to your partner
- **Background location:** Updates your position even when the app is backgrounded
- **Secure storage:** Device ID and couple code stored in iOS Keychain (not UserDefaults)
- **Unpair:** Clears all data on server and locally

### Configuration

The backend URL is read from `Info.plist` key `API_BASE_URL`. It defaults to the production Railway deployment. To point to a local server during development, change it in the Info.plist or pass an environment variable.

### Key Design Decisions

- **Keychain over UserDefaults:** Sensitive identifiers (device ID, couple code) are stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlock` for background access.
- **No accounts:** The app uses randomly generated device UUIDs. No email, no passwords, no sign-up.
- **Privacy first:** Only the latest location is stored. No history. No analytics. No third-party SDKs.
- **Single Map view:** The prior version used a separate compass screen. The new native app combines the map, compass indicator, distance, and poke into one clean view.

## App Store Submission

See `appstore/SUBMISSION_CHECKLIST.md` for the complete step-by-step guide. Key materials:
- Privacy policy: `appstore/privacy-policy.md` (host this at a public URL)
- Store listing text: `appstore/app-store-description.md`

## Data and Privacy

- Only the latest location per device is stored; no history
- Coordinates never appear in server logs
- `is_sharing=false` hides coordinates from partner
- Pairing codes are cryptographically generated (32^8 combinations)
- 2-device limit per couple
- All API traffic is HTTPS with HSTS in production
- Rate limiting prevents brute-force and abuse

## License

Personal project -- not for public distribution.
