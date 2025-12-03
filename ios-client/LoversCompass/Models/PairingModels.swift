import Foundation

struct PairingRequest: Codable {
    let action: String          // "create" or "join"
    let device_id: String       // this device's ID
    let couple_id: String?      // couple code for join, nil for create
}

struct PairingResponse: Codable {
    let couple_id: String
    let device_id: String
    let role: String
    let existing_devices: Int?   // ← make this optional
}
