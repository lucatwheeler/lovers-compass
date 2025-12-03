import SwiftUI
import CoreLocation

struct MainView: View {
    let deviceId: String
    let coupleId: String

    private let apiClient = APIClient.shared

    @StateObject private var locationManager = LocationManager()
    @StateObject private var headingManager = HeadingManager()

    @State private var partnerLocation: CLLocationCoordinate2D?
    @State private var partnerConnected: Bool = false
    @State private var staleness: Int?
    @State private var syncTimer: Timer?
    @State private var showDebugInfo: Bool = false

    // Sync interval in seconds
    private let syncInterval: TimeInterval = 10

    // MARK: - Computed Properties

    private var distanceText: String {
        guard let my = locationManager.currentLocation, let partner = partnerLocation else {
            return ""
        }
        let meters = CompassCalculator.distance(
            from: my,
            to: partner
        )
        return CompassCalculator.formatDistance(meters)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.97),
                    Color(red: 0.98, green: 0.95, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                headerView

                Spacer()

                // Permission denied view OR compass
                if locationManager.isDenied {
                    permissionDeniedView
                } else {
                    // The compass
                    CompassView(
                        myLocation: locationManager.currentLocation,
                        partnerLocation: partnerLocation,
                        deviceHeading: headingManager.heading,
                        partnerConnected: partnerConnected,
                        staleness: staleness
                    )

                    // Distance badge
                    if partnerConnected && !distanceText.isEmpty {
                        DistanceBadgeView(distance: distanceText, staleness: staleness)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()

                // Status footer
                footerView
            }
            .padding()
        }
        .onAppear {
            startServices()
        }
        .onDisappear {
            stopServices()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Lover's Compass")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.pink)

            // Couple ID as a subtle badge
            Text(coupleId)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.gray.opacity(0.1))
                )
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.pink.opacity(0.5))

            Text("Location Access Needed")
                .font(.headline)
                .foregroundColor(.gray)

            Text("Enable location access so the compass can point toward your partner")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                locationManager.openSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.pink)
                    )
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 8) {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(partnerConnected ? .green : .orange)
                    .frame(width: 8, height: 8)

                Text(partnerConnected ? "Connected" : "Searching for partner...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Debug toggle (tap to show/hide details)
            if showDebugInfo {
                debugInfoView
            }
        }
        .onTapGesture {
            withAnimation {
                showDebugInfo.toggle()
            }
        }
    }

    // MARK: - Debug Info

    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let loc = locationManager.currentLocation {
                Text("You: \(String(format: "%.4f, %.4f", loc.latitude, loc.longitude))")
            }
            if let partner = partnerLocation {
                Text("Partner: \(String(format: "%.4f, %.4f", partner.latitude, partner.longitude))")
            }
            Text("Heading: \(String(format: "%.0f°", headingManager.heading))")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.gray.opacity(0.6))
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.1))
        )
    }
}

// MARK: - Services

extension MainView {

    private func startServices() {
        // Start location updates
        if locationManager.isNotDetermined {
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            locationManager.startUpdating()
        }

        // Start heading updates (compass)
        headingManager.startUpdating()

        // Start periodic sync timer
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { await syncOnce() }
        }

        // Initial sync after short delay
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await syncOnce()
        }
    }

    private func stopServices() {
        locationManager.stopUpdating()
        headingManager.stopUpdating()
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func syncOnce() async {
        await sendMyLocation()
        await fetchPartnerLocation()
    }

    private func sendMyLocation() async {
        guard let location = locationManager.currentLocation else { return }

        let request = LocationUpdateRequest(
            couple_id: coupleId,
            device_id: deviceId,
            is_sharing: true,
            latitude: location.latitude,
            longitude: location.longitude
        )

        do {
            _ = try await apiClient.updateLocation(request)
        } catch {
            print("Send location error: \(error)")
        }
    }

    private func fetchPartnerLocation() async {
        do {
            let response = try await apiClient.getPartnerLocation(
                coupleId: coupleId,
                deviceId: deviceId
            )

            await MainActor.run {
                if !response.partner_found {
                    partnerConnected = false
                    partnerLocation = nil
                    staleness = nil
                    return
                }

                if response.is_sharing != true {
                    partnerConnected = false
                    partnerLocation = nil
                    staleness = response.staleness_seconds
                    return
                }

                if let lat = response.latitude, let lon = response.longitude {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        partnerConnected = true
                        partnerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        staleness = response.staleness_seconds
                    }
                }
            }
        } catch {
            print("Fetch partner error: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(deviceId: "TEST-DEVICE", coupleId: "LOVE1234")
}
