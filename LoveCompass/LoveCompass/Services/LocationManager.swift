import Foundation
import CoreLocation
import UIKit

/// Manages device location and compass heading using a single CLLocationManager.
/// Heading and location share the same authorized manager so heading actually works.
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var currentLocation: CLLocationCoordinate2D?
    /// Continuous heading that never wraps (avoids 359->1 animation glitch).
    /// Use this for rotation animations.
    @Published var heading: Double = 0
    @Published var headingAvailable: Bool = false

    /// Tracks cumulative rotation so we always take the short path.
    private var rawHeading: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
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

    private let manager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        super.init()
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20
        manager.headingFilter = kCLHeadingFilterNone
    }

    // MARK: - Public Methods

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
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

        if CLLocationManager.headingAvailable() {
            headingAvailable = true
            manager.startUpdatingHeading()
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
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

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let newRaw = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading

        DispatchQueue.main.async {
            // Calculate shortest-path delta to avoid the 359->1 wraparound glitch
            var delta = newRaw - self.rawHeading.truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            self.rawHeading += delta
            self.heading = self.rawHeading
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
