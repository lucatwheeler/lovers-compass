import XCTest
import CoreLocation
@testable import LoveCompass

final class CompassCalculatorTests: XCTestCase {

    // MARK: - Bearing Tests

    func testBearingNorth() {
        // Point due north: same longitude, higher latitude
        let from = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let to = CLLocationCoordinate2D(latitude: 41.0, longitude: -74.0)
        let bearing = CompassCalculator.bearing(from: from, to: to)
        // Should be approximately 0 degrees (north)
        XCTAssertEqual(bearing, 0, accuracy: 1.0, "Bearing due north should be ~0 degrees")
    }

    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 41.0, longitude: -74.0)
        let to = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        let bearing = CompassCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 180, accuracy: 1.0, "Bearing due south should be ~180 degrees")
    }

    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let to = CLLocationCoordinate2D(latitude: 0.0, longitude: 1.0)
        let bearing = CompassCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 90, accuracy: 1.0, "Bearing due east should be ~90 degrees")
    }

    func testBearingWest() {
        let from = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let to = CLLocationCoordinate2D(latitude: 0.0, longitude: -1.0)
        let bearing = CompassCalculator.bearing(from: from, to: to)
        XCTAssertEqual(bearing, 270, accuracy: 1.0, "Bearing due west should be ~270 degrees")
    }

    func testBearingAlwaysPositive() {
        // Bearing should always be in [0, 360)
        let coords: [(Double, Double)] = [
            (40.7128, -74.0060),   // NYC
            (51.5074, -0.1278),    // London
            (35.6762, 139.6503),   // Tokyo
            (-33.8688, 151.2093),  // Sydney
        ]

        for i in 0..<coords.count {
            for j in 0..<coords.count where i != j {
                let from = CLLocationCoordinate2D(latitude: coords[i].0, longitude: coords[i].1)
                let to = CLLocationCoordinate2D(latitude: coords[j].0, longitude: coords[j].1)
                let bearing = CompassCalculator.bearing(from: from, to: to)
                XCTAssertGreaterThanOrEqual(bearing, 0, "Bearing should be >= 0")
                XCTAssertLessThan(bearing, 360, "Bearing should be < 360")
            }
        }
    }

    func testBearingSamePoint() {
        let point = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let bearing = CompassCalculator.bearing(from: point, to: point)
        // Bearing to self is undefined, but should not crash and should return a number
        XCTAssertFalse(bearing.isNaN, "Bearing to same point should not be NaN")
    }

    // MARK: - Distance Tests

    func testDistanceSamePoint() {
        let point = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let distance = CompassCalculator.distance(from: point, to: point)
        XCTAssertEqual(distance, 0, accuracy: 0.1, "Distance to same point should be 0")
    }

    func testDistanceKnownRoute() {
        // NYC to London: approximately 5,570 km
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let distance = CompassCalculator.distance(from: nyc, to: london)
        let km = distance / 1000.0
        XCTAssertEqual(km, 5570, accuracy: 50, "NYC to London should be ~5,570 km")
    }

    func testDistanceIsSymmetric() {
        let a = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let b = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        let d1 = CompassCalculator.distance(from: a, to: b)
        let d2 = CompassCalculator.distance(from: b, to: a)
        XCTAssertEqual(d1, d2, accuracy: 0.01, "Distance should be symmetric")
    }

    func testDistanceAlwaysNonNegative() {
        let coords: [(Double, Double)] = [
            (40.7128, -74.0060),
            (51.5074, -0.1278),
            (-33.8688, 151.2093),
            (0.0, 0.0),
        ]

        for i in 0..<coords.count {
            for j in 0..<coords.count {
                let from = CLLocationCoordinate2D(latitude: coords[i].0, longitude: coords[i].1)
                let to = CLLocationCoordinate2D(latitude: coords[j].0, longitude: coords[j].1)
                let distance = CompassCalculator.distance(from: from, to: to)
                XCTAssertGreaterThanOrEqual(distance, 0, "Distance should never be negative")
            }
        }
    }

    // MARK: - Format Distance Tests

    func testFormatDistanceFeet() {
        // Under 0.1 miles (~161m) should show feet
        XCTAssertEqual(CompassCalculator.formatDistance(30), "98 ft")
        XCTAssertEqual(CompassCalculator.formatDistance(0), "0 ft")
    }

    func testFormatDistanceMilesWithDecimal() {
        // 1609m = 1 mile
        XCTAssertEqual(CompassCalculator.formatDistance(1609), "1.0 mi")
        XCTAssertEqual(CompassCalculator.formatDistance(8047), "5.0 mi")
    }

    func testFormatDistanceLargeMiles() {
        // Over 10 miles shows whole number
        XCTAssertEqual(CompassCalculator.formatDistance(32187), "20 mi")
        XCTAssertEqual(CompassCalculator.formatDistance(160934), "100 mi")
    }
}
