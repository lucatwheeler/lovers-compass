import Foundation
import CoreLocation
import UIKit

/// Manages device location with background update support.
/// Publishes the current coordinate and authorization status for SwiftUI views to observe.
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationError: String?

    // MARK: - Computed Properties

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Private Properties

    private let manager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        self.authorizationStatus = CLLocationManager.authorizationStatus()
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Public Methods

    /// Request "Always" location permission for background tracking.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Upgrade to Always permission after initial When-In-Use grant.
    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

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

        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

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
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
            self.locationError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if !self.isDenied {
                self.locationError = "Unable to get location: \(error.localizedDescription)"
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.isAuthorized {
                self.startUpdating()
                // After getting When-In-Use, request upgrade to Always
                if manager.authorizationStatus == .authorizedWhenInUse {
                    self.requestAlwaysPermission()
                }
            } else if self.isDenied {
                self.locationError = "Location permission denied. Please enable in Settings."
            }
        }
    }
}
