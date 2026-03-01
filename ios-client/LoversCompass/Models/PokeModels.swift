import Foundation

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
