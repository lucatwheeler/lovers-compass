import Foundation
import CoreLocation
import UIKit

/// Manages device location for foreground-only GPS tracking.
/// Uses "When In Use" authorization for battery efficiency.
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Current device location (nil until first GPS fix)
    @Published var currentLocation: CLLocationCoordinate2D?

    /// Current authorization status for location services
    @Published var authorizationStatus: CLAuthorizationStatus

    /// Human-readable error message for UI display
    @Published var locationError: String?

    // MARK: - Computed Properties

    /// Whether we have sufficient permission to get location
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Whether permission has been explicitly denied
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Whether we haven't asked for permission yet
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        // Get initial authorization status
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update when moved 10 meters
    }

    // MARK: - Public Methods

    /// Request "When In Use" location permission from user
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Start receiving location updates (foreground only)
    func startUpdating() {
        locationError = nil

        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services are disabled on this device."
            return
        }

        guard isAuthorized else {
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        locationManager.startUpdatingLocation()
    }

    /// Stop receiving location updates (call when view disappears)
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    /// Open iOS Settings app to allow user to change permissions
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }

        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update published property on main thread
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
            self.locationError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            // Don't overwrite denial errors with generic location errors
            if !self.isDenied {
                self.locationError = "Unable to get location: \(error.localizedDescription)"
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            // Auto-start updates if permission was just granted
            if self.isAuthorized {
                self.startUpdating()
            } else if self.isDenied {
                self.locationError = "Location permission denied. Please enable in Settings."
            }
        }
    }
}
