import SwiftUI
import UserNotifications

@main
struct LoveCompassApp: App {

    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notification permission granted: \(granted)")
        }
    }
}

// MARK: - Root View

/// Decides whether to show the pairing flow or the main compass view
/// based on whether the user has already paired.
struct RootView: View {
    @State private var isPaired: Bool = false
    @State private var coupleId: String = ""
    @State private var deviceId: String = ""

    var body: some View {
        Group {
            if isPaired {
                NavigationStack {
                    MapView(
                        deviceId: deviceId,
                        coupleId: coupleId,
                        onUnpair: handleUnpair
                    )
                }
            } else {
                PairingView(onPaired: handlePaired)
            }
        }
        .onAppear {
            deviceId = KeychainService.shared.getOrCreateDeviceId()
            if let saved = KeychainService.shared.getCoupleId() {
                coupleId = saved
                isPaired = true
            }
        }
    }

    private func handlePaired(_ newCoupleId: String) {
        KeychainService.shared.saveCoupleId(newCoupleId)
        coupleId = newCoupleId
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = true
        }
    }

    private func handleUnpair() {
        KeychainService.shared.deleteCoupleId()
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = false
            coupleId = ""
        }
    }
}
