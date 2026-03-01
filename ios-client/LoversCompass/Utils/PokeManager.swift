import Foundation
import UserNotifications

@MainActor
final class PokeManager: ObservableObject {
    @Published var showPokeBanner: Bool = false
    @Published var showPokeSentToast: Bool = false
    @Published var isSendingPoke: Bool = false

    private let apiClient = APIClient.shared
    private var pollTimer: Timer?

    private let coupleId: String
    private let deviceId: String

    init(coupleId: String, deviceId: String) {
        self.coupleId = coupleId
        self.deviceId = deviceId
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.checkForPokes()
            }
        }
        // Immediate first check
        Task { await checkForPokes() }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func sendPoke() async {
        guard !isSendingPoke else { return }
        isSendingPoke = true

        do {
            _ = try await apiClient.sendPoke(coupleId: coupleId, deviceId: deviceId)
            showPokeSentToast = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showPokeSentToast = false
        } catch {
            print("Failed to send poke: \(error)")
        }

        isSendingPoke = false
    }

    private func checkForPokes() async {
        do {
            let response = try await apiClient.getPokes(coupleId: coupleId, deviceId: deviceId)
            if response.pokes > 0 {
                showPokeBanner = true
                fireLocalNotification()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                showPokeBanner = false
            }
        } catch {
            print("Failed to check pokes: \(error)")
        }
    }

    private func fireLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "\u{1F497} Lover's Compass"
        content.body = "Your partner poked you!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "poke-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Local notification error: \(error)")
            }
        }
    }
}
