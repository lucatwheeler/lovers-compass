import Foundation
import CoreLocation

/// Calculates bearing and distance between two coordinates.
/// Used to determine which direction the compass heart should point.
enum CompassCalculator {

    /// Calculate the bearing (direction) from one coordinate to another.
    ///
    /// - Parameters:
    ///   - from: Starting coordinate (your location)
    ///   - to: Target coordinate (partner's location)
    /// - Returns: Bearing in degrees (0-360), where 0 = North, 90 = East, etc.
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lon1 = from.longitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let lon2 = to.longitude.toRadians()

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing.toDegrees()

        // Normalize to 0-360
        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate the distance between two coordinates.
    ///
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Target coordinate
    /// - Returns: Distance in meters
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    /// Format distance for display in a human-friendly way.
    ///
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string (e.g., "150 m", "2.3 km", "15 km")
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

// MARK: - Degree/Radian Conversion

private extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }

    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}
