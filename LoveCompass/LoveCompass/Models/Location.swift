import Foundation

// MARK: - Location Update

struct LocationUpdateRequest: Codable {
    let couple_id: String
    let device_id: String
    let is_sharing: Bool
    let latitude: Double
    let longitude: Double
}

struct LocationUpdateResponse: Codable {
    let success: Bool
    let updated_at: String
}

// MARK: - Partner Location

struct PartnerLocationResponse: Codable {
    let partner_found: Bool
    let is_sharing: Bool?
    let latitude: Double?
    let longitude: Double?
    let updated_at: String?
    let staleness_seconds: Int?
}
