import XCTest
@testable import LoveCompass

final class ModelTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - PairingRequest

    func testPairingRequestCreateEncoding() throws {
        let request = PairingRequest(action: "create", device_id: "test-device", couple_id: nil)
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["action"] as? String, "create")
        XCTAssertEqual(json["device_id"] as? String, "test-device")
    }

    func testPairingRequestJoinEncoding() throws {
        let request = PairingRequest(action: "join", device_id: "dev-123", couple_id: "ABCD1234")
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["action"] as? String, "join")
        XCTAssertEqual(json["couple_id"] as? String, "ABCD1234")
    }

    // MARK: - PairingResponse

    func testPairingResponseDecoding() throws {
        let json = """
        {"couple_id": "ABCD1234", "device_id": "dev-123", "role": "creator", "existing_devices": 1}
        """.data(using: .utf8)!

        let response = try decoder.decode(PairingResponse.self, from: json)
        XCTAssertEqual(response.couple_id, "ABCD1234")
        XCTAssertEqual(response.device_id, "dev-123")
        XCTAssertEqual(response.role, "creator")
        XCTAssertEqual(response.existing_devices, 1)
    }

    func testPairingResponseDecodingWithoutOptional() throws {
        let json = """
        {"couple_id": "ABCD1234", "device_id": "dev-123", "role": "joiner"}
        """.data(using: .utf8)!

        let response = try decoder.decode(PairingResponse.self, from: json)
        XCTAssertNil(response.existing_devices)
    }

    // MARK: - LocationUpdateRequest

    func testLocationUpdateRequestEncoding() throws {
        let request = LocationUpdateRequest(
            couple_id: "ABCD1234",
            device_id: "dev-123",
            is_sharing: true,
            latitude: 40.7128,
            longitude: -74.0060
        )
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["couple_id"] as? String, "ABCD1234")
        XCTAssertEqual(json["is_sharing"] as? Bool, true)
        XCTAssertEqual(json["latitude"] as? Double, 40.7128)
        XCTAssertEqual(json["longitude"] as? Double, -74.0060)
    }

    // MARK: - LocationUpdateResponse

    func testLocationUpdateResponseDecoding() throws {
        let json = """
        {"success": true, "updated_at": "2026-03-14T12:00:00Z"}
        """.data(using: .utf8)!

        let response = try decoder.decode(LocationUpdateResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.updated_at, "2026-03-14T12:00:00Z")
    }

    // MARK: - PartnerLocationResponse

    func testPartnerLocationFoundDecoding() throws {
        let json = """
        {
            "partner_found": true,
            "is_sharing": true,
            "latitude": 51.5074,
            "longitude": -0.1278,
            "updated_at": "2026-03-14T12:00:00Z",
            "staleness_seconds": 30
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PartnerLocationResponse.self, from: json)
        XCTAssertTrue(response.partner_found)
        XCTAssertEqual(response.is_sharing, true)
        XCTAssertEqual(response.latitude, 51.5074)
        XCTAssertEqual(response.longitude, -0.1278)
        XCTAssertEqual(response.staleness_seconds, 30)
    }

    func testPartnerLocationNotFoundDecoding() throws {
        let json = """
        {"partner_found": false}
        """.data(using: .utf8)!

        let response = try decoder.decode(PartnerLocationResponse.self, from: json)
        XCTAssertFalse(response.partner_found)
        XCTAssertNil(response.latitude)
        XCTAssertNil(response.longitude)
        XCTAssertNil(response.staleness_seconds)
    }

    // MARK: - PokeRequest

    func testPokeRequestEncoding() throws {
        let request = PokeRequest(couple_id: "ABCD1234", device_id: "dev-123", message: nil)
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["couple_id"] as? String, "ABCD1234")
        XCTAssertEqual(json["device_id"] as? String, "dev-123")
    }

    func testPokeRequestEncodingWithMessage() throws {
        let request = PokeRequest(couple_id: "ABCD1234", device_id: "dev-123", message: "miss you 🥺")
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["message"] as? String, "miss you 🥺")
    }

    // MARK: - PokeResponse

    func testPokeResponseDecoding() throws {
        let json = """
        {"success": true, "message": "Poke sent!"}
        """.data(using: .utf8)!

        let response = try decoder.decode(PokeResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.message, "Poke sent!")
    }

    // MARK: - PokesResponse

    func testPokesResponseDecoding() throws {
        let json = """
        {"pokes": 3, "latest_at": "2026-03-14T12:00:00Z"}
        """.data(using: .utf8)!

        let response = try decoder.decode(PokesResponse.self, from: json)
        XCTAssertEqual(response.pokes, 3)
        XCTAssertEqual(response.latest_at, "2026-03-14T12:00:00Z")
    }

    func testPokesResponseZeroDecoding() throws {
        let json = """
        {"pokes": 0, "latest_at": null}
        """.data(using: .utf8)!

        let response = try decoder.decode(PokesResponse.self, from: json)
        XCTAssertEqual(response.pokes, 0)
        XCTAssertNil(response.latest_at)
    }

    func testPokesResponseWithMessagesDecoding() throws {
        let json = """
        {"pokes": 2, "latest_at": "2026-03-14T12:00:00Z", "messages": [
            {"message": "hey cutie 💘", "created_at": "2026-03-14T11:59:00Z"},
            {"message": null, "created_at": "2026-03-14T12:00:00Z"}
        ]}
        """.data(using: .utf8)!

        let response = try decoder.decode(PokesResponse.self, from: json)
        XCTAssertEqual(response.pokes, 2)
        XCTAssertEqual(response.messages?.count, 2)
        XCTAssertEqual(response.messages?.first?.message, "hey cutie 💘")
        XCTAssertNil(response.messages?.last?.message)
    }

    // MARK: - UnpairResponse

    func testUnpairResponseDecoding() throws {
        let json = """
        {"success": true, "message": "Couple removed", "devices_removed": 2}
        """.data(using: .utf8)!

        let response = try decoder.decode(UnpairResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.devices_removed, 2)
    }
}
