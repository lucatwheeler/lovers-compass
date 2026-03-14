# Love Compass - App Store Submission Checklist

A step-by-step guide to getting Love Compass from Xcode to the App Store.

---

## Phase 1: Apple Developer Account

- [ ] **Enroll in the Apple Developer Program** ($99/year)
  - Go to https://developer.apple.com/programs/
  - Sign in with your Apple ID
  - Complete enrollment (may take 24-48 hours for approval)
- [ ] **Accept all agreements** in App Store Connect
  - Go to https://appstoreconnect.apple.com
  - Check for any pending agreements (especially the Paid Apps agreement, even for free apps)

## Phase 2: Certificates and Provisioning

- [ ] **Create a signing certificate** (Xcode does this automatically)
  - Open the LoveCompass project in Xcode
  - Go to Signing & Capabilities tab
  - Select your team (your Apple Developer account)
  - Xcode will create certificates automatically
- [ ] **Set the Bundle Identifier**
  - Currently set to `com.lovecompass.app`
  - Change to match your developer account (e.g., `com.yourname.lovecompass`)
  - Update in Xcode project settings > General > Bundle Identifier
- [ ] **Enable required capabilities** in Signing & Capabilities
  - Background Modes > Location updates (check the box)
  - Push Notifications (for future remote push support)
- [ ] **Verify the Info.plist** has all required keys
  - NSLocationWhenInUseUsageDescription
  - NSLocationAlwaysAndWhenInUseUsageDescription
  - NSLocationAlwaysUsageDescription
  - UIBackgroundModes includes "location"
  - ITSAppUsesNonExemptEncryption = NO

## Phase 3: Build and Test on Device

- [ ] **Connect a physical iPhone** (iOS 17+)
- [ ] **Build and run** (Cmd+R) -- verify no build errors
- [ ] **Test the full flow:**
  - [ ] Create a couple on Device A
  - [ ] Join the couple on Device B using the code
  - [ ] Verify both locations appear on the map
  - [ ] Verify the compass indicator points correctly
  - [ ] Verify distance display is accurate
  - [ ] Send a poke from A to B and verify notification
  - [ ] Send a poke from B to A and verify notification
  - [ ] Background the app, move, verify location updates
  - [ ] Open Settings, verify couple code display
  - [ ] Unpair and verify return to pairing screen
  - [ ] Force-quit and relaunch -- verify pairing is remembered
- [ ] **Test edge cases:**
  - [ ] Deny location permission -- verify the warning banner appears
  - [ ] No internet -- verify graceful error handling
  - [ ] Enter invalid pairing code -- verify error message
  - [ ] Rate limit -- rapid-fire location updates should not crash

## Phase 4: TestFlight (Internal Testing)

- [ ] **Create the app in App Store Connect**
  - Go to https://appstoreconnect.apple.com > My Apps > + New App
  - Platform: iOS
  - Name: Love Compass
  - Primary Language: English (U.S.)
  - Bundle ID: (select the one matching your project)
  - SKU: lovecompass-v1
- [ ] **Archive the app in Xcode**
  - Select "Any iOS Device" as destination (not a simulator)
  - Product > Archive
  - Wait for the archive to complete
- [ ] **Upload to App Store Connect**
  - In the Organizer window (Window > Organizer), select the archive
  - Click "Distribute App"
  - Select "App Store Connect"
  - Follow the prompts (Xcode handles signing)
  - Wait for upload and processing (5-15 minutes)
- [ ] **Set up TestFlight**
  - In App Store Connect, go to your app > TestFlight tab
  - The build should appear after processing
  - Add yourself and Gianna as internal testers
  - Both testers download TestFlight app and accept the invite
- [ ] **Test via TestFlight** -- repeat the testing from Phase 3

## Phase 5: App Store Metadata

- [ ] **Fill in App Store listing**
  - App Information:
    - Name: Love Compass
    - Subtitle: Always pointing to your heart
    - Category: Lifestyle (primary), Navigation (secondary)
  - Pricing: Free
  - Privacy Policy URL: (host privacy-policy.md and enter URL)
  - Description: (use the text from app-store-description.md)
  - Keywords: couple, location, compass, partner, sharing, love, relationship, map, distance, poke
  - Support URL: (your contact page or email)
  - What's New: Initial release
- [ ] **Upload screenshots**
  - Required: iPhone 6.7" (iPhone 15 Pro Max)
  - Recommended: iPhone 6.1", iPhone 5.5"
  - Take screenshots using the Simulator or real device
  - Minimum 3 screenshots, maximum 10
  - Screenshots needed:
    1. Pairing screen
    2. Map with both locations
    3. Compass pointing to partner
    4. Poke received notification
    5. Settings screen
- [ ] **Upload app icon**
  - Xcode should include this from the asset catalog
  - Verify it appears correctly in App Store Connect
- [ ] **App Review Information**
  - Contact: Your name and email
  - Demo account: Not needed (the app does not use accounts)
  - Notes: Include the testing instructions from app-store-description.md

## Phase 6: App Privacy (Required)

- [ ] **Complete the App Privacy section** in App Store Connect
  - Go to App Information > App Privacy
  - Data types collected:
    - Location > Precise Location
      - Purpose: App Functionality
      - Linked to user: No (device IDs are random)
      - Tracking: No
    - Identifiers > Device ID
      - Purpose: App Functionality
      - Linked to user: No
      - Tracking: No
  - Data NOT collected: (check none for all other categories)

## Phase 7: Submit for Review

- [ ] **Select the build** in the App Store version page
- [ ] **Complete all required fields** (the page will show warnings for missing items)
- [ ] **Set the release option:**
  - "Manually release this version" (recommended for first release)
  - Or "Automatically release" if you want it live immediately after approval
- [ ] **Click "Submit for Review"**
- [ ] **Wait for review** (typically 24-48 hours, sometimes faster)
  - You will receive email notifications about the review status
  - If rejected, read the rejection reason carefully and fix the issue

## Phase 8: Post-Launch

- [ ] **Monitor for crashes** in App Store Connect > Analytics
- [ ] **Respond to any App Review feedback** promptly
- [ ] **Update the backend** if needed (Railway auto-deploys from main branch)
- [ ] **Consider future updates:**
  - Remote push notifications (requires APNs setup)
  - Widgets showing partner distance
  - Apple Watch companion app
  - iMessage stickers

---

## Quick Reference: Key Settings

| Setting | Value |
|---------|-------|
| Xcode project | `LoveCompass/LoveCompass.xcodeproj` |
| Bundle ID | `com.lovecompass.app` (change to your own) |
| Deployment target | iOS 17.0 |
| Swift version | 5.0 |
| Device | iPhone only |
| Orientation | Portrait only |
| Backend URL | `https://web-production-558a2.up.railway.app` |
| API Base URL config | Info.plist > API_BASE_URL |

---

## Troubleshooting

**"No eligible devices" error in Xcode:**
- Connect a physical iPhone running iOS 17+
- Or select a simulator from the device dropdown

**"Signing requires a development team" error:**
- Go to Signing & Capabilities
- Select your Apple Developer team

**Archive fails:**
- Make sure you selected "Any iOS Device" as the build destination
- Clean the build folder (Product > Clean Build Folder)

**Upload fails with "invalid binary":**
- Check that the bundle ID matches what is registered in App Store Connect
- Ensure the version and build number are set correctly

**App rejected for location usage:**
- Make sure all three NSLocation*UsageDescription strings clearly explain WHY location is needed
- Demonstrate that location is core to the app's functionality in your review notes
