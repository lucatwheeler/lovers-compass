import SwiftUI
import MapKit
import CoreLocation

/// The main screen after pairing. Shows a MapKit map with both users' locations,
/// a compass overlay that points toward the partner, and a poke button.
struct MapView: View {
    let deviceId: String
    let coupleId: String
    var onUnpair: (() -> Void)? = nil

    private let api = APIService.shared

    @StateObject private var locationManager = LocationManager()
    @StateObject private var headingManager = HeadingManager()

    @State private var partnerLocation: CLLocationCoordinate2D?
    @State private var partnerConnected: Bool = false
    @State private var staleness: Int?
    @State private var syncTimer: Timer?
    @State private var showSettings: Bool = false
    @State private var isSharing: Bool = true

    // Map state
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Poke state
    @State private var pokeManager: PokeManager?

    private let syncInterval: TimeInterval = 10

    // Theme colors
    private let rosePink = Color(red: 1.0, green: 0.42, blue: 0.54)
    private let deepRose = Color(red: 1.0, green: 0.27, blue: 0.44)

    // MARK: - Computed

    private var distanceText: String {
        guard let my = locationManager.currentLocation, let partner = partnerLocation else {
            return ""
        }
        let meters = CompassCalculator.distance(from: my, to: partner)
        return CompassCalculator.formatDistance(meters)
    }

    private var heartRotation: Double {
        guard let my = locationManager.currentLocation, let partner = partnerLocation else {
            return 0
        }
        let bearing = CompassCalculator.bearing(from: my, to: partner)
        return bearing - headingManager.heading
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            mapLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerOverlay
                Spacer()
                bottomOverlay
            }

            // Poke received banner
            if let pm = pokeManager, pm.showPokeBanner {
                VStack {
                    pokeBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .animation(.spring(response: 0.5), value: pm.showPokeBanner)
                .padding(.top, 100)
            }

            // Poke sent toast
            if let pm = pokeManager, pm.showPokeSentToast {
                VStack {
                    Spacer()
                    Text("Poke sent!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(rosePink)
                                .shadow(color: rosePink.opacity(0.4), radius: 10)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 160)
                }
                .animation(.spring(response: 0.4), value: pm.showPokeSentToast)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            let pm = PokeManager(coupleId: coupleId, deviceId: deviceId)
            pokeManager = pm
            startServices()
            pm.startPolling()
        }
        .onDisappear {
            stopServices()
            pokeManager?.stopPolling()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                coupleId: coupleId,
                deviceId: deviceId,
                onUnpair: {
                    onUnpair?()
                }
            )
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            // My location marker
            if let myLoc = locationManager.currentLocation {
                Annotation("You", coordinate: myLoc) {
                    ZStack {
                        Circle()
                            .fill(rosePink.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        Circle()
                            .fill(rosePink)
                            .frame(width: 16, height: 16)
                    }
                }
            }

            // Partner location marker
            if let partnerLoc = partnerLocation, partnerConnected {
                Annotation("Partner", coordinate: partnerLoc) {
                    ZStack {
                        Circle()
                            .fill(deepRose.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(deepRose)
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapUserLocationButton()
        }
    }

    // MARK: - Header Overlay

    private var headerOverlay: some View {
        HStack(alignment: .top) {
            // Compass indicator
            compassIndicator
                .padding(.leading, 16)

            Spacer()

            VStack(spacing: 4) {
                Text("Love Compass")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(deepRose)

                HStack(spacing: 6) {
                    Circle()
                        .fill(partnerConnected ? .green : .orange)
                        .frame(width: 7, height: 7)
                    Text(partnerConnected ? "Connected" : "Searching...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(rosePink.opacity(0.7))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Compass Indicator

    private var compassIndicator: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            if partnerConnected && locationManager.currentLocation != nil && partnerLocation != nil {
                // Heart needle pointing to partner
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(deepRose)
                    .rotationEffect(.degrees(heartRotation))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: heartRotation)
            } else {
                // Pulsing heart when not connected
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
    }

    // MARK: - Bottom Overlay

    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            // Distance and staleness
            if partnerConnected && !distanceText.isEmpty {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(distanceText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(deepRose)
                        Text("apart")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if let s = staleness {
                        VStack(spacing: 2) {
                            Text(formatStaleness(s))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(s > 300 ? .orange : .secondary)
                            Text("last update")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )
            }

            // Permission warning
            if locationManager.isDenied {
                locationDeniedBanner
            }

            // Poke button
            pokeButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    // MARK: - Location Denied Banner

    private var locationDeniedBanner: some View {
        Button {
            locationManager.openSettings()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location Access Needed")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tap to open Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.orange)
        }
    }

    // MARK: - Poke Button

    private var pokeButton: some View {
        Button {
            Task { await pokeManager?.sendPoke() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                Text("Poke Your Partner")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [rosePink, deepRose],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: rosePink.opacity(0.35), radius: 12, y: 5)
            )
        }
        .disabled(pokeManager?.isSendingPoke == true)
        .opacity(pokeManager?.isSendingPoke == true ? 0.6 : 1.0)
    }

    // MARK: - Poke Banner

    private var pokeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
            Text("Your partner is thinking of you!")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [rosePink, deepRose],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: rosePink.opacity(0.4), radius: 15, y: 5)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func formatStaleness(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}

// MARK: - Services

extension MapView {

    private func startServices() {
        if locationManager.isNotDetermined {
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            locationManager.startUpdating()
        }

        headingManager.startUpdating()

        // Start periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { await syncOnce() }
        }

        // Initial sync after a short delay
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
            is_sharing: isSharing,
            latitude: location.latitude,
            longitude: location.longitude
        )

        do {
            _ = try await api.updateLocation(request)
        } catch {
            print("Send location error: \(error)")
        }
    }

    private func fetchPartnerLocation() async {
        do {
            let response = try await api.getPartnerLocation(
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

// MARK: - Heading Manager

/// Manages device heading (compass direction) using the magnetometer.
final class HeadingManager: NSObject, ObservableObject {

    @Published var heading: Double = 0
    @Published var isAvailable: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        isAvailable = CLLocationManager.headingAvailable()
    }

    func startUpdating() {
        guard CLLocationManager.headingAvailable() else {
            isAvailable = false
            return
        }
        isAvailable = true
        manager.headingFilter = 1
        manager.startUpdatingHeading()
    }

    func stopUpdating() {
        manager.stopUpdatingHeading()
    }
}

extension HeadingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            if newHeading.trueHeading >= 0 {
                self.heading = newHeading.trueHeading
            } else {
                self.heading = newHeading.magneticHeading
            }
        }
    }
}

// MARK: - Compass Calculator

/// Calculates bearing and distance between two coordinates.
enum CompassCalculator {

    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180.0 / .pi

        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else if meters < 10000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f km", meters / 1000)
        }
    }
}

// MARK: - Poke Manager

/// Manages sending and receiving pokes between partners.
@MainActor
final class PokeManager: ObservableObject {
    @Published var showPokeBanner: Bool = false
    @Published var showPokeSentToast: Bool = false
    @Published var isSendingPoke: Bool = false

    private let api = APIService.shared
    private var pollTimer: Timer?
    private let coupleId: String
    private let deviceId: String

    init(coupleId: String, deviceId: String) {
        self.coupleId = coupleId
        self.deviceId = deviceId
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.checkForPokes()
            }
        }
        Task { await checkForPokes() }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func sendPoke() async {
        guard !isSendingPoke else { return }
        isSendingPoke = true

        do {
            _ = try await api.sendPoke(coupleId: coupleId, deviceId: deviceId)
            showPokeSentToast = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showPokeSentToast = false
        } catch {
            print("Failed to send poke: \(error)")
        }

        isSendingPoke = false
    }

    private func checkForPokes() async {
        do {
            let response = try await api.getPokes(coupleId: coupleId, deviceId: deviceId)
            if response.pokes > 0 {
                showPokeBanner = true
                fireLocalNotification()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                showPokeBanner = false
            }
        } catch {
            print("Failed to check pokes: \(error)")
        }
    }

    private func fireLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Love Compass"
        content.body = "Your partner poked you!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "poke-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Local notification error: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MapView(deviceId: "TEST-DEVICE", coupleId: "LOVE1234")
    }
}
