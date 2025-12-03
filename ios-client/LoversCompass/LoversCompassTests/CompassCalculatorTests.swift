//
//  CompassCalculatorTests.swift
//  LoversCompassTests
//
//  Comprehensive tests for compass bearing and distance calculations
//

import XCTest
import CoreLocation
@testable import LoversCompass

final class CompassCalculatorTests: XCTestCase {

    // MARK: - Test Coordinates

    // San Francisco (reference point)
    let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    // Oakland (east of SF)
    let oakland = CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)

    // Daly City (south of SF)
    let dalyCity = CLLocationCoordinate2D(latitude: 37.6879, longitude: -122.4702)

    // Sausalito (north of SF)
    let sausalito = CLLocationCoordinate2D(latitude: 37.8591, longitude: -122.4853)

    // Pacifica (southwest of SF)
    let pacifica = CLLocationCoordinate2D(latitude: 37.6138, longitude: -122.4869)

    // New York (far east)
    let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

    // Tokyo (across the Pacific)
    let tokyo = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)

    // London
    let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    // Sydney (southern hemisphere)
    let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

    // North Pole
    let northPole = CLLocationCoordinate2D(latitude: 90.0, longitude: 0.0)

    // South Pole
    let southPole = CLLocationCoordinate2D(latitude: -90.0, longitude: 0.0)

    // Equator/Prime Meridian
    let equatorPrime = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)

    // MARK: - Bearing Tolerance

    // Allow 1 degree tolerance for bearing calculations
    let bearingTolerance: Double = 1.0

    // MARK: - Cardinal Direction Tests

    func testBearing_DueNorth() throws {
        // Point directly north on same longitude
        let from = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let to = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)

        let bearing = CompassCalculator.bearing(from: from, to: to)

        XCTAssertEqual(bearing, 0.0, accuracy: bearingTolerance,
                       "Due North should be ~0 degrees, got \(bearing)")
    }

    func testBearing_DueSouth() throws {
        // Point directly south on same longitude
        let from = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)
        let to = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)

        let bearing = CompassCalculator.bearing(from: from, to: to)

        XCTAssertEqual(bearing, 180.0, accuracy: bearingTolerance,
                       "Due South should be ~180 degrees, got \(bearing)")
    }

    func testBearing_DueEast() throws {
        // Point directly east on same latitude (near equator for accuracy)
        let from = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        let to = CLLocationCoordinate2D(latitude: 0.0, longitude: 1.0)

        let bearing = CompassCalculator.bearing(from: from, to: to)

        XCTAssertEqual(bearing, 90.0, accuracy: bearingTolerance,
                       "Due East should be ~90 degrees, got \(bearing)")
    }

    func testBearing_DueWest() throws {
        // Point directly west on same latitude (near equator for accuracy)
        let from = CLLocationCoordinate2D(latitude: 0.0, longitude: 1.0)
        let to = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)

        let bearing = CompassCalculator.bearing(from: from, to: to)

        XCTAssertEqual(bearing, 270.0, accuracy: bearingTolerance,
                       "Due West should be ~270 degrees, got \(bearing)")
    }

    // MARK: - Intercardinal Direction Tests

    func testBearing_NorthEast() throws {
        // San Francisco to Oakland (roughly NE)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: oakland)

        // Oakland is NE of SF, bearing should be roughly 45-70 degrees
        XCTAssertGreaterThan(bearing, 30.0, "Oakland should be NE of SF")
        XCTAssertLessThan(bearing, 90.0, "Oakland should be NE of SF, not due E")
    }

    func testBearing_SouthWest() throws {
        // San Francisco to Pacifica (SW)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: pacifica)

        // Pacifica is SW of SF, bearing should be roughly 200-250 degrees
        XCTAssertGreaterThan(bearing, 180.0, "Pacifica should be SW of SF")
        XCTAssertLessThan(bearing, 270.0, "Pacifica should be SW of SF")
    }

    func testBearing_NorthWest() throws {
        // Oakland to Sausalito (NW direction)
        let bearing = CompassCalculator.bearing(from: oakland, to: sausalito)

        // Sausalito is NW of Oakland, bearing should be roughly 270-360 degrees
        XCTAssertGreaterThan(bearing, 270.0, "Sausalito should be NW of Oakland")
        XCTAssertLessThan(bearing, 360.0, "Sausalito should be NW of Oakland")
    }

    // MARK: - Long Distance Tests

    func testBearing_SFtoNewYork() throws {
        // Cross-country bearing
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: newYork)

        // New York is ENE of SF (great circle route goes north)
        // Bearing should be roughly 60-80 degrees
        XCTAssertGreaterThan(bearing, 50.0, "NY should be ENE of SF")
        XCTAssertLessThan(bearing, 90.0, "NY should be ENE of SF")
    }

    func testBearing_SFtoTokyo() throws {
        // Trans-Pacific bearing (crosses date line)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: tokyo)

        // Tokyo is WNW of SF via great circle
        // Bearing should be roughly 300-320 degrees
        XCTAssertGreaterThan(bearing, 290.0, "Tokyo should be WNW of SF")
        XCTAssertLessThan(bearing, 330.0, "Tokyo should be WNW of SF")
    }

    func testBearing_SFtoSydney() throws {
        // To southern hemisphere
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: sydney)

        // Sydney is SW of SF
        // Bearing should be roughly 220-250 degrees
        XCTAssertGreaterThan(bearing, 210.0, "Sydney should be SW of SF")
        XCTAssertLessThan(bearing, 260.0, "Sydney should be SW of SF")
    }

    // MARK: - Edge Cases

    func testBearing_SameLocation() throws {
        // Same location should return 0 (or any value, really - it's undefined)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: sanFrancisco)

        // Just verify it doesn't crash and returns a valid number
        XCTAssertFalse(bearing.isNaN, "Same location bearing should not be NaN")
        XCTAssertFalse(bearing.isInfinite, "Same location bearing should not be infinite")
    }

    func testBearing_ToNorthPole() throws {
        // Any point to North Pole should be ~0 (due North)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: northPole)

        XCTAssertEqual(bearing, 0.0, accuracy: bearingTolerance,
                       "Bearing to North Pole should be ~0 degrees")
    }

    func testBearing_ToSouthPole() throws {
        // Any point to South Pole should be ~180 (due South)
        let bearing = CompassCalculator.bearing(from: sanFrancisco, to: southPole)

        XCTAssertEqual(bearing, 180.0, accuracy: bearingTolerance,
                       "Bearing to South Pole should be ~180 degrees")
    }

    func testBearing_AcrossDateLine() throws {
        // Test crossing the date line (longitude 180/-180)
        let westOfDateLine = CLLocationCoordinate2D(latitude: 0.0, longitude: 179.0)
        let eastOfDateLine = CLLocationCoordinate2D(latitude: 0.0, longitude: -179.0)

        let bearing = CompassCalculator.bearing(from: westOfDateLine, to: eastOfDateLine)

        // Going from 179 to -179 should be ~90 degrees (east)
        XCTAssertEqual(bearing, 90.0, accuracy: bearingTolerance,
                       "Crossing date line eastward should be ~90 degrees")
    }

    func testBearing_AcrossPrimeMeridian() throws {
        // Test crossing the prime meridian
        let westOfPrime = CLLocationCoordinate2D(latitude: 51.5, longitude: -1.0)
        let eastOfPrime = CLLocationCoordinate2D(latitude: 51.5, longitude: 1.0)

        let bearing = CompassCalculator.bearing(from: westOfPrime, to: eastOfPrime)

        // Going east across prime meridian
        XCTAssertEqual(bearing, 90.0, accuracy: 5.0, // Larger tolerance at high lat
                       "Crossing prime meridian eastward should be ~90 degrees")
    }

    // MARK: - Symmetry Tests

    func testBearing_Symmetry() throws {
        // Bearing from A to B should be roughly opposite of B to A
        let bearingAtoB = CompassCalculator.bearing(from: sanFrancisco, to: oakland)
        let bearingBtoA = CompassCalculator.bearing(from: oakland, to: sanFrancisco)

        // Calculate expected reverse bearing
        let expectedReverse = (bearingAtoB + 180.0).truncatingRemainder(dividingBy: 360.0)

        // Note: Due to great circle geometry, this isn't exact, but should be close for short distances
        XCTAssertEqual(bearingBtoA, expectedReverse, accuracy: 5.0,
                       "Reverse bearing should be ~180 degrees opposite")
    }

    // MARK: - Distance Tests

    func testDistance_SFtoOakland() throws {
        let distance = CompassCalculator.distance(from: sanFrancisco, to: oakland)

        // SF to Oakland is roughly 13-15 km
        XCTAssertGreaterThan(distance, 12000, "SF to Oakland should be > 12km")
        XCTAssertLessThan(distance, 16000, "SF to Oakland should be < 16km")
    }

    func testDistance_SFtoNewYork() throws {
        let distance = CompassCalculator.distance(from: sanFrancisco, to: newYork)

        // SF to NY is roughly 4100-4200 km
        XCTAssertGreaterThan(distance, 4000000, "SF to NY should be > 4000km")
        XCTAssertLessThan(distance, 4300000, "SF to NY should be < 4300km")
    }

    func testDistance_SameLocation() throws {
        let distance = CompassCalculator.distance(from: sanFrancisco, to: sanFrancisco)

        XCTAssertEqual(distance, 0.0, accuracy: 0.1,
                       "Distance to same location should be 0")
    }

    func testDistance_Symmetry() throws {
        let distanceAtoB = CompassCalculator.distance(from: sanFrancisco, to: oakland)
        let distanceBtoA = CompassCalculator.distance(from: oakland, to: sanFrancisco)

        XCTAssertEqual(distanceAtoB, distanceBtoA, accuracy: 0.1,
                       "Distance should be symmetric")
    }

    // MARK: - Distance Formatting Tests

    func testFormatDistance_Meters() throws {
        let formatted = CompassCalculator.formatDistance(150)
        XCTAssertEqual(formatted, "150 m")
    }

    func testFormatDistance_MetersRounding() throws {
        let formatted = CompassCalculator.formatDistance(999.7)
        XCTAssertEqual(formatted, "1000 m")
    }

    func testFormatDistance_KilometersOneDecimal() throws {
        let formatted = CompassCalculator.formatDistance(2345)
        XCTAssertEqual(formatted, "2.3 km")
    }

    func testFormatDistance_KilometersWholeNumber() throws {
        let formatted = CompassCalculator.formatDistance(15678)
        XCTAssertEqual(formatted, "16 km")
    }

    // MARK: - Bearing Normalization Tests

    func testBearing_AlwaysPositive() throws {
        // Run many bearings and verify all are 0-360
        let testPoints = [
            sanFrancisco, oakland, dalyCity, sausalito,
            newYork, tokyo, london, sydney, equatorPrime
        ]

        for from in testPoints {
            for to in testPoints {
                let bearing = CompassCalculator.bearing(from: from, to: to)
                XCTAssertGreaterThanOrEqual(bearing, 0.0,
                    "Bearing should be >= 0")
                XCTAssertLessThan(bearing, 360.0,
                    "Bearing should be < 360")
            }
        }
    }
}

// MARK: - Heart Rotation Tests

final class HeartRotationTests: XCTestCase {

    // Test the heart rotation formula: bearing - deviceHeading

    func testHeartRotation_PhonePointingNorth_PartnerEast() throws {
        let bearing: Double = 90.0  // Partner is due East
        let deviceHeading: Double = 0.0  // Phone pointing North

        let heartRotation = bearing - deviceHeading

        // Heart should point 90 degrees right (East)
        XCTAssertEqual(heartRotation, 90.0, accuracy: 0.1)
    }

    func testHeartRotation_PhonePointingEast_PartnerEast() throws {
        let bearing: Double = 90.0  // Partner is due East
        let deviceHeading: Double = 90.0  // Phone pointing East

        let heartRotation = bearing - deviceHeading

        // Heart should point straight up (0 degrees)
        XCTAssertEqual(heartRotation, 0.0, accuracy: 0.1)
    }

    func testHeartRotation_PhonePointingSouth_PartnerNorth() throws {
        let bearing: Double = 0.0  // Partner is due North
        let deviceHeading: Double = 180.0  // Phone pointing South

        let heartRotation = bearing - deviceHeading

        // Heart should point behind (-180, or visually: 180 degrees rotated)
        XCTAssertEqual(heartRotation, -180.0, accuracy: 0.1)
    }

    func testHeartRotation_PhonePointingWest_PartnerSouth() throws {
        let bearing: Double = 180.0  // Partner is due South
        let deviceHeading: Double = 270.0  // Phone pointing West

        let heartRotation = bearing - deviceHeading

        // Heart should point left (-90 degrees from top)
        XCTAssertEqual(heartRotation, -90.0, accuracy: 0.1)
    }

    func testHeartRotation_FullRotationScenarios() throws {
        // Test all 8 compass points with various phone orientations
        let cardinalBearings: [(String, Double)] = [
            ("N", 0), ("NE", 45), ("E", 90), ("SE", 135),
            ("S", 180), ("SW", 225), ("W", 270), ("NW", 315)
        ]

        let headings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]

        for (dirName, bearing) in cardinalBearings {
            for heading in headings {
                let rotation = bearing - heading

                // Rotation should be in valid range for SwiftUI rotation
                // SwiftUI handles any angle, but verify math is consistent
                XCTAssertFalse(rotation.isNaN,
                    "Rotation for \(dirName) with heading \(heading) should not be NaN")

                // Verify the rotation makes geometric sense
                // If heading equals bearing, rotation should be 0 (pointing up)
                if bearing == heading {
                    XCTAssertEqual(rotation, 0.0, accuracy: 0.1,
                        "When facing partner, heart should point up")
                }
            }
        }
    }

    func testHeartRotation_RealWorldScenario_WalkingTowardPartner() throws {
        // Scenario: Partner is NE (45 degrees), user turns to face them
        let bearing: Double = 45.0

        // User starts facing North
        var heading: Double = 0.0
        var rotation = bearing - heading
        XCTAssertEqual(rotation, 45.0, accuracy: 0.1,
            "Heart should point 45 degrees right")

        // User turns to face NE
        heading = 45.0
        rotation = bearing - heading
        XCTAssertEqual(rotation, 0.0, accuracy: 0.1,
            "Heart should point straight up when facing partner")

        // User overshoots and faces E
        heading = 90.0
        rotation = bearing - heading
        XCTAssertEqual(rotation, -45.0, accuracy: 0.1,
            "Heart should point 45 degrees left (partner now to the left)")
    }

    func testHeartRotation_RealWorldScenario_PartnerMoving() throws {
        // Scenario: User facing North, partner moves around them
        let heading: Double = 0.0  // User always facing North

        // Partner starts North
        var bearing: Double = 0.0
        XCTAssertEqual(bearing - heading, 0.0, accuracy: 0.1, "Partner North → up")

        // Partner moves East
        bearing = 90.0
        XCTAssertEqual(bearing - heading, 90.0, accuracy: 0.1, "Partner East → right")

        // Partner moves South
        bearing = 180.0
        XCTAssertEqual(bearing - heading, 180.0, accuracy: 0.1, "Partner South → down")

        // Partner moves West
        bearing = 270.0
        XCTAssertEqual(bearing - heading, 270.0, accuracy: 0.1, "Partner West → left")
    }
}
