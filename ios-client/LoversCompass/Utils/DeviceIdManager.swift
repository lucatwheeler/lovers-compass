import Foundation

final class DeviceIdManager {
    private let key = "loversCompass.deviceId"
    
    func getDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
