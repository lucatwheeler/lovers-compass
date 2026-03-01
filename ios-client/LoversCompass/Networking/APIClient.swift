import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://web-production-558a2.up.railway.app")!
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    enum APIError: Error, LocalizedError {
        case badStatus(Int)
        case decodingFailed(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .badStatus(let code):
                return "Server error (status \(code))"
            case .decodingFailed(let body):
                return "Failed to decode response. Body: \(body)"
            case .unknown:
                return "Unknown error"
            }
        }
    }

    // MARK: - Pair

    func pair(_ request: PairingRequest) async throws -> PairingResponse {
        let url = baseURL.appendingPathComponent("pair")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(PairingResponse.self, from: data)
        } catch {
            print("PAIR decode error:", error, bodyString)
            throw APIError.decodingFailed(bodyString)
        }
    }

    // MARK: - Location

    func updateLocation(_ request: LocationUpdateRequest) async throws -> LocationUpdateResponse {
        let url = baseURL.appendingPathComponent("updateLocation")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(LocationUpdateResponse.self, from: data)
        } catch {
            print("UPDATE decode error:", error, bodyString)
            throw APIError.decodingFailed(bodyString)
        }
    }

    func getPartnerLocation(coupleId: String, deviceId: String) async throws -> PartnerLocationResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("partnerLocation"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "couple_id", value: coupleId),
            URLQueryItem(name: "device_id", value: deviceId)
        ]
        guard let url = components.url else {
            throw APIError.unknown
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(PartnerLocationResponse.self, from: data)
        } catch {
            print("PARTNER decode error:", error, bodyString)
            throw APIError.decodingFailed(bodyString)
        }
    }

    // MARK: - Poke

    func sendPoke(coupleId: String, deviceId: String) async throws -> PokeResponse {
        let url = baseURL.appendingPathComponent("poke")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PokeRequest(couple_id: coupleId, device_id: deviceId)
        urlRequest.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(PokeResponse.self, from: data)
        } catch {
            print("POKE decode error:", error, bodyString)
            throw APIError.decodingFailed(bodyString)
        }
    }

    func getPokes(coupleId: String, deviceId: String) async throws -> PokesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("pokes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "couple_id", value: coupleId),
            URLQueryItem(name: "device_id", value: deviceId)
        ]
        guard let url = components.url else {
            throw APIError.unknown
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(PokesResponse.self, from: data)
        } catch {
            print("POKES decode error:", error, bodyString)
            throw APIError.decodingFailed(bodyString)
        }
    }
}
