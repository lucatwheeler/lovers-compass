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
    /// Bearer token for this device. Returned once at pairing; stored in the Keychain.
    let auth_token: String?
}

// MARK: - Auth

struct TokenRequest: Codable {
    let couple_id: String
    let device_id: String
}

struct TokenResponse: Codable {
    let auth_token: String
}

// MARK: - Push Registration

struct PushRegisterRequest: Codable {
    let couple_id: String
    let device_id: String
    let push_token: String
    let platform: String
}

struct PushRegisterResponse: Codable {
    let success: Bool
}

// MARK: - Poke

struct PokeRequest: Codable {
    let couple_id: String
    let device_id: String
    /// Optional personal message shown to the recipient.
    let message: String?
}

struct PokeResponse: Codable {
    let success: Bool
    let message: String
}

struct ReceivedPoke: Codable {
    let message: String?
    let created_at: String
}

struct PokesResponse: Codable {
    let pokes: Int
    let latest_at: String?
    /// Unseen pokes, oldest first. Optional so older servers still decode.
    let messages: [ReceivedPoke]?
}

// MARK: - Unpair

struct UnpairResponse: Codable {
    let success: Bool
    let message: String
    let devices_removed: Int
}
