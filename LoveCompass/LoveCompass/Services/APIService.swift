import Foundation

/// Centralized API client for all backend communication.
/// The base URL is read from the app bundle's configuration (Info.plist
/// API_BASE_URL) or falls back to the production Render deployment.
/// All post-pairing requests carry the device's bearer token.
final class APIService {
    static let shared = APIService()

    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let session: URLSession

    // MARK: - Errors

    enum APIError: Error, LocalizedError {
        case badStatus(Int, String)
        case decodingFailed(String)
        case invalidURL
        case unknown

        /// HTTP status code for badStatus errors (nil otherwise).
        var statusCode: Int? {
            if case .badStatus(let code, _) = self { return code }
            return nil
        }

        var errorDescription: String? {
            switch self {
            case .badStatus(let code, let body):
                // Show the server's "detail" message when present instead of raw JSON
                if let data = body.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = obj["detail"] as? String {
                    return detail
                }
                return "Server error (status \(code))"
            case .decodingFailed(let body):
                return "Failed to decode response: \(body)"
            case .invalidURL:
                return "Invalid URL"
            case .unknown:
                return "An unknown error occurred"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Read the base URL from the Info.plist or fall back to production
        let urlString: String
        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !configured.isEmpty {
            urlString = configured
        } else {
            urlString = "https://lovers-compass.onrender.com"
        }
        guard let url = URL(string: urlString) else {
            fatalError("Invalid API base URL: \(urlString)")
        }
        self.baseURL = url

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Pairing

    func pair(_ request: PairingRequest) async throws -> PairingResponse {
        return try await post(path: "pair", body: request)
    }

    // MARK: - Auth

    /// One-time token claim for devices paired before token auth existed.
    func claimToken(coupleId: String, deviceId: String) async throws -> TokenResponse {
        let body = TokenRequest(couple_id: coupleId, device_id: deviceId)
        return try await post(path: "auth/token", body: body)
    }

    // MARK: - Location

    func updateLocation(_ request: LocationUpdateRequest) async throws -> LocationUpdateResponse {
        return try await post(path: "updateLocation", body: request)
    }

    func getPartnerLocation(coupleId: String, deviceId: String) async throws -> PartnerLocationResponse {
        return try await get(
            path: "partnerLocation",
            queryItems: [
                URLQueryItem(name: "couple_id", value: coupleId),
                URLQueryItem(name: "device_id", value: deviceId)
            ]
        )
    }

    // MARK: - Poke

    func sendPoke(coupleId: String, deviceId: String, message: String? = nil) async throws -> PokeResponse {
        let body = PokeRequest(couple_id: coupleId, device_id: deviceId, message: message)
        return try await post(path: "poke", body: body)
    }

    func getPokes(coupleId: String, deviceId: String) async throws -> PokesResponse {
        return try await get(
            path: "pokes",
            queryItems: [
                URLQueryItem(name: "couple_id", value: coupleId),
                URLQueryItem(name: "device_id", value: deviceId)
            ]
        )
    }

    // MARK: - Unpair

    func unpair(coupleId: String, deviceId: String) async throws -> UnpairResponse {
        return try await delete(
            path: "api/pair/\(coupleId)",
            queryItems: [
                URLQueryItem(name: "device_id", value: deviceId)
            ]
        )
    }

    // MARK: - Push Registration

    func registerPushToken(coupleId: String, deviceId: String, pushToken: String) async throws -> PushRegisterResponse {
        let body = PushRegisterRequest(
            couple_id: coupleId, device_id: deviceId,
            push_token: pushToken, platform: "ios"
        )
        return try await post(path: "push/register", body: body)
    }

    // MARK: - Invite Links

    /// HTTPS invite link for a couple code. Opens the app if installed,
    /// otherwise a landing page with App Store / web fallbacks.
    func inviteURL(for coupleId: String) -> URL {
        baseURL.appendingPathComponent("join").appendingPathComponent(coupleId)
    }

    /// Shareable invite message for a couple code.
    func inviteMessage(for coupleId: String) -> String {
        "Be my lover on Lover's Compass! 💘 Tap to pair with me: \(inviteURL(for: coupleId).absoluteString) (or enter code \(coupleId) in the app)"
    }

    // MARK: - Health

    func healthCheck() async throws -> Bool {
        let _: [String: String] = try await get(path: "health", queryItems: [])
        return true
    }

    // MARK: - Private Helpers

    private func post<B: Encodable, R: Decodable>(path: String, body: B) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(body)
        return try await execute(urlRequest)
    }

    private func get<R: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> R {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        return try await execute(urlRequest)
    }

    private func delete<R: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> R {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        return try await execute(urlRequest)
    }

    private func execute<R: Decodable>(_ urlRequest: URLRequest) async throws -> R {
        var urlRequest = urlRequest
        if let token = KeychainService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, bodyString)
        }

        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            throw APIError.decodingFailed(bodyString)
        }
    }
}
