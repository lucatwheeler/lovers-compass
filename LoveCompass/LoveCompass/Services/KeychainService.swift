import Foundation
import Security

/// Secure storage for sensitive identifiers (device ID, couple ID) using the iOS Keychain.
/// Non-sensitive preferences remain in UserDefaults.
final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.ltw.lovecompass"
    private let deviceIdKey = "deviceId"
    private let coupleIdKey = "coupleId"
    private let authTokenKey = "authToken"

    private init() {}

    // MARK: - Device ID

    /// Returns the stored device ID, or generates and stores a new one.
    func getOrCreateDeviceId() -> String {
        if let existing = read(key: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        save(key: deviceIdKey, value: newId)
        return newId
    }

    // MARK: - Couple ID

    func getCoupleId() -> String? {
        return read(key: coupleIdKey)
    }

    func saveCoupleId(_ coupleId: String) {
        save(key: coupleIdKey, value: coupleId)
    }

    func deleteCoupleId() {
        delete(key: coupleIdKey)
    }

    // MARK: - Auth Token

    func getAuthToken() -> String? {
        return read(key: authTokenKey)
    }

    func saveAuthToken(_ token: String) {
        save(key: authTokenKey, value: token)
    }

    func deleteAuthToken() {
        delete(key: authTokenKey)
    }

    /// Clear all stored credentials (used during full reset).
    func clearAll() {
        delete(key: deviceIdKey)
        delete(key: coupleIdKey)
        delete(key: authTokenKey)
    }

    // MARK: - Keychain Operations

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error for key \(key): \(status)")
        }
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
