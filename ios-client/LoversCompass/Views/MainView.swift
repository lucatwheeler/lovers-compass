import SwiftUI

struct MainView: View {
    let deviceId: String
    let coupleId: String

    private let apiClient = APIClient.shared

    @StateObject private var locationManager = LocationManager()

    @State private var lastUpdateStatus: String = "Waiting for GPS..."
    @State private var partnerStatus: String = "Partner location not fetched yet."
    @State private var partnerCoords: (lat: Double, lon: Double)?
    @State private var syncTimer: Timer?

    // Sync interval in seconds
    private let syncInterval: TimeInterval = 10

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Lover's Compass")
                    .font(.largeTitle.bold())

                Text("Couple ID: \(coupleId)")
                    .font(.footnote.monospaced())
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Location permission denied view
                if locationManager.isDenied {
                    permissionDeniedView
                } else {
                    // Normal operation view
                    statusView
                }

                Spacer()
            }
            .padding()
            .onAppear {
                startLocationServices()
            }
            .onDisappear {
                stopLocationServices()
            }
        }
    }

    // MARK: - Subviews

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))

            Text("Location Access Required")
                .font(.headline)

            Text("Lover's Compass needs your location to point toward your partner. Please enable location access in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                locationManager.openSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var statusView: some View {
        VStack(spacing: 16) {
            // My location status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(locationManager.currentLocation != nil ? .green : .orange)
                    Text("My Location")
                        .font(.headline)
                }

                if let location = locationManager.currentLocation {
                    Text(String(format: "(%.4f, %.4f)", location.latitude, location.longitude))
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                } else if locationManager.isNotDetermined {
                    Text("Requesting permission...")
                        .font(.footnote)
                        .foregroundColor(.orange)
                } else {
                    Text("Acquiring GPS signal...")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }

                Text(lastUpdateStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.05))
            .cornerRadius(12)

            // Partner location status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(partnerCoords != nil ? .pink : .gray)
                    Text("Partner Location")
                        .font(.headline)
                }

                if let coords = partnerCoords {
                    Text(String(format: "(%.4f, %.4f)", coords.lat, coords.lon))
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                }

                Text(partnerStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pink.opacity(0.05))
            .cornerRadius(12)

            // Error display
            if let error = locationManager.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Manual sync button (for debugging/testing)
            Button {
                Task { await syncOnce() }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

// MARK: - Location Services

extension MainView {

    private func startLocationServices() {
        // Request permission and start GPS
        if locationManager.isNotDetermined {
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            locationManager.startUpdating()
        }

        // Start periodic sync timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { await syncOnce() }
        }

        // Initial sync after short delay to let GPS acquire
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await syncOnce()
        }
    }

    private func stopLocationServices() {
        locationManager.stopUpdating()
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func syncOnce() async {
        await sendMyLocation()
        await fetchPartnerLocation()
    }

    private func sendMyLocation() async {
        guard let location = locationManager.currentLocation else {
            lastUpdateStatus = "No GPS fix yet"
            return
        }

        let request = LocationUpdateRequest(
            couple_id: coupleId,
            device_id: deviceId,
            is_sharing: true,
            latitude: location.latitude,
            longitude: location.longitude
        )

        do {
            let response = try await apiClient.updateLocation(request)
            let time = response.updated_at.suffix(8) // Just show time portion
            lastUpdateStatus = "Sent at \(time)"
        } catch {
            lastUpdateStatus = "Send failed: \(error.localizedDescription)"
        }
    }

    private func fetchPartnerLocation() async {
        do {
            let response = try await apiClient.getPartnerLocation(
                coupleId: coupleId,
                deviceId: deviceId
            )

            if !response.partner_found {
                partnerStatus = "No partner found yet"
                partnerCoords = nil
                return
            }

            if response.is_sharing != true {
                partnerStatus = "Partner not sharing"
                partnerCoords = nil
                return
            }

            if let lat = response.latitude, let lon = response.longitude {
                partnerCoords = (lat, lon)
                let stale = response.staleness_seconds ?? 0
                partnerStatus = "Updated \(stale)s ago"
            } else {
                partnerStatus = "No coordinates available"
                partnerCoords = nil
            }
        } catch {
            partnerStatus = "Fetch failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(deviceId: "TEST-DEVICE", coupleId: "TESTCODE")
}
