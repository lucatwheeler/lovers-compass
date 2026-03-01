import Foundation

final class DeviceIdManager {
    private let deviceIdKey = "loversCompass.deviceId"
    private let coupleIdKey = "loversCompass.coupleId"

    func getDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }

    var savedCoupleId: String? {
        UserDefaults.standard.string(forKey: coupleIdKey)
    }

    func saveCoupleId(_ coupleId: String) {
        UserDefaults.standard.set(coupleId, forKey: coupleIdKey)
    }

    func clearCoupleId() {
        UserDefaults.standard.removeObject(forKey: coupleIdKey)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: coupleIdKey)
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
    }
}
