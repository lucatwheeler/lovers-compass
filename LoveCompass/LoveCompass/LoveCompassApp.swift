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

struct RootView: View {
    @State private var isPaired: Bool = false
    @State private var coupleId: String = ""
    @State private var deviceId: String = ""
    @State private var deepLinkCode: String? = nil

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
                PairingView(onPaired: handlePaired, prefillCode: deepLinkCode)
            }
        }
        .onAppear {
            deviceId = KeychainService.shared.getOrCreateDeviceId()
            if let saved = KeychainService.shared.getCoupleId() {
                coupleId = saved
                isPaired = true
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handlePaired(_ newCoupleId: String) {
        KeychainService.shared.saveCoupleId(newCoupleId)
        coupleId = newCoupleId
        deepLinkCode = nil
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

    private func handleDeepLink(_ url: URL) {
        // Handles: loverscompass://join/ABCD1234
        guard url.scheme == "loverscompass",
              url.host == "join",
              let code = url.pathComponents.last,
              code.count == 8 else { return }

        if isPaired {
            // Already paired — ignore
            return
        }

        deepLinkCode = code.uppercased()
    }
}
