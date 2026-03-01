# Lover's Compass iOS Client — Build Notes

## What Was Built

### Persistence (Task 7)
- **DeviceIdManager.swift** — Extended to save/restore `couple_id` via UserDefaults
- **LoversCompassApp.swift** — New `RootView` checks for saved pairing and skips PairingView on relaunch
- Users no longer need to re-pair after closing and reopening the app

### Poke Feature (Task 1)
- **PokeModels.swift** (new) — Request/response models for poke API
- **PokeManager.swift** (new) — Manages poke sending, polling (every 5s), and local notification delivery
- **APIClient.swift** — Added `sendPoke()` and `getPokes()` methods
- **MainView.swift** — Big pink "Poke your partner" button at bottom; animated toast on send; pink banner on receive with pulsing heart animation
- **LoversCompassApp.swift** — Requests `UNUserNotificationCenter` permission on launch
- Local notifications fire when pokes are received (works in foreground and background)
- Backend endpoints already existed: `POST /poke` and `GET /pokes`

### Settings Screen (Task 2)
- **SettingsView.swift** (new) — Shows couple code (large, copyable), share button, unpair button with confirmation, and "About" section
- **MainView.swift** — Gear icon in top-right opens settings as a sheet
- Unpair action clears UserDefaults and navigates back to PairingView

### Romantic Theme Polish (Task 3)
- **ContentView.swift** (PairingView) — Complete redesign:
  - Pink gradient background
  - White rounded card container for pairing controls
  - Pink branded title with "Always pointing to your heart" tagline
  - Pink gradient buttons (not default gray)
  - Copy button for couple code
  - Pulsing heart animation while waiting for partner
  - Large monospace couple code display in pink-bordered box

### Info.plist & Location Permissions (Tasks 4 & 6)
- **Info.plist** (new) — Created with all three location usage descriptions and `UIBackgroundModes: location`
- **project.pbxproj** — Updated build settings with `INFOPLIST_FILE` reference and all `INFOPLIST_KEY_NSLocation*` descriptions
- **LocationManager.swift** — Updated for background location:
  - `requestAlwaysAuthorization()` (was `requestWhenInUseAuthorization`)
  - `allowsBackgroundLocationUpdates = true`
  - `pausesLocationUpdatesAutomatically = false`
  - `desiredAccuracy = kCLLocationAccuracyHundredMeters` (battery friendly)
  - `distanceFilter = 50` meters

### App Icon (Task 5)
- **scripts/generate_icon.py** — Python/Pillow script generates a 1024x1024 pink heart icon
- **AppIcon-1024.png** — Rose-to-deep-pink gradient background, centered white heart with subtle shadow
- **Contents.json** — Updated to reference the generated icon

### Project Structure (Task 8)
- **project.pbxproj** — All 3 new Swift files registered (PokeModels.swift, PokeManager.swift, SettingsView.swift) + Info.plist

## Files Changed
- `LoversCompass/LoversCompass/LoversCompassApp.swift` — Rewritten with RootView, persistence, notification setup
- `LoversCompass/LoversCompass/ContentView.swift` — Complete romantic redesign of PairingView
- `LoversCompass/Views/MainView.swift` — Added poke button/banner, settings gear, onUnpair callback
- `LoversCompass/Networking/APIClient.swift` — Added poke API methods
- `LoversCompass/Utils/DeviceIdManager.swift` — Added couple_id persistence
- `LoversCompass/Utils/LocationManager.swift` — Background location support
- `LoversCompass/LoversCompass.xcodeproj/project.pbxproj` — New files + Info.plist + build settings

## Files Created
- `LoversCompass/Models/PokeModels.swift`
- `LoversCompass/Utils/PokeManager.swift`
- `LoversCompass/Views/SettingsView.swift`
- `LoversCompass/LoversCompass/Info.plist`
- `LoversCompass/LoversCompass/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- `scripts/generate_icon.py`

## How to Open & Run

```bash
open LoversCompass/LoversCompass.xcodeproj
```

1. Select your team in **Signing & Capabilities** (currently set to Luca's team 8MBGHS687J)
2. Select a physical iPhone as the run destination (compass requires real device)
3. Build and run (Cmd+R)

## Known Limitations

- **Remote push notifications** require an Apple Developer account and APNs configuration — only local notifications are implemented (these work for foreground poke delivery)
- **Backend URL is hardcoded** in `APIClient.swift` to `https://web-production-558a2.up.railway.app` — change this if the backend moves
- **Background location** requires the "Location updates" background mode capability to be enabled in Xcode's Signing & Capabilities tab (the Info.plist key is set, but Xcode may need the entitlement toggled manually)
- **Compass heading** requires a real device with magnetometer — simulator will show 0 heading
- The app polls for pokes every 5 seconds and syncs location every 10 seconds — battery impact is minimal due to `kCLLocationAccuracyHundredMeters`
