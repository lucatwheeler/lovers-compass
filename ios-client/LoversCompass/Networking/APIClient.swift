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
        print("PAIR status:", http.statusCode)
        
        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("PAIR raw body:", bodyString)
        
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(PairingResponse.self, from: data)
            print("PAIR decoded:", decoded)
            return decoded
        } catch {
            print("PAIR decode error:", error)
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
        print("UPDATE status:", http.statusCode)
        
        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("UPDATE raw body:", bodyString)
        
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(LocationUpdateResponse.self, from: data)
            print("UPDATE decoded:", decoded)
            return decoded
        } catch {
            print("UPDATE decode error:", error)
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
        print("PARTNER status:", http.statusCode)
        
        let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("PARTNER raw body:", bodyString)
        
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        
        do {
            let decoded = try decoder.decode(PartnerLocationResponse.self, from: data)
            print("PARTNER decoded:", decoded)
            return decoded
        } catch {
            print("PARTNER decode error:", error)
            throw APIError.decodingFailed(bodyString)
        }
    }
}
