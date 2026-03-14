import Foundation

// MARK: - Pairing

struct PairingRequest: Codable {
    let action: String
    let device_id: String
    let couple_id: String?
}

struct PairingResponse: Codable {
    let couple_id: String
    let device_id: String
    let role: String
    let existing_devices: Int?
}

// MARK: - Poke

struct PokeRequest: Codable {
    let couple_id: String
    let device_id: String
}

struct PokeResponse: Codable {
    let success: Bool
    let message: String
}

struct PokesResponse: Codable {
    let pokes: Int
    let latest_at: String?
}

// MARK: - Unpair

struct UnpairResponse: Codable {
    let success: Bool
    let message: String
    let devices_removed: Int
}
