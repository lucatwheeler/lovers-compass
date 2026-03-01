import Foundation
import CoreLocation
import UIKit

/// Manages device location with background location support.
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

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Public Methods

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
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

        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
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
            } else if self.isDenied {
                self.locationError = "Location permission denied. Please enable in Settings."
            }
        }
    }
}
