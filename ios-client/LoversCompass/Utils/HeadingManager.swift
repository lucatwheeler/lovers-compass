import Foundation
import CoreLocation

/// Manages device heading (compass direction) using the magnetometer.
/// Provides real-time updates of which direction the phone is pointing.
final class HeadingManager: NSObject, ObservableObject {

    /// Current device heading in degrees (0-360, where 0 = North)
    @Published var heading: Double = 0

    /// Whether heading updates are available on this device
    @Published var isAvailable: Bool = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        isAvailable = CLLocationManager.headingAvailable()
    }

    /// Start receiving heading updates
    func startUpdating() {
        guard CLLocationManager.headingAvailable() else {
            isAvailable = false
            return
        }
        isAvailable = true
        locationManager.headingFilter = 1 // Update when heading changes by 1 degree
        locationManager.startUpdatingHeading()
    }

    /// Stop receiving heading updates
    func stopUpdating() {
        locationManager.stopUpdatingHeading()
    }
}

// MARK: - CLLocationManagerDelegate

extension HeadingManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use magnetic heading (works without calibration)
        // True heading requires location fix and is slightly more accurate
        DispatchQueue.main.async {
            if newHeading.trueHeading >= 0 {
                self.heading = newHeading.trueHeading
            } else {
                self.heading = newHeading.magneticHeading
            }
        }
    }
}
