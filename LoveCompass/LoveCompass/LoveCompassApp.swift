import SwiftUI
import UserNotifications

@main
struct LoveCompassApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
            if granted {
                // Register with APNs so pokes arrive even when the app is closed
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - App Delegate (APNs registration callbacks)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushRegistrar.shared.updateAPNsToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
    }
}

// MARK: - Push Registrar

/// Uploads the APNs device token to the backend once both the token and a
/// pairing exist. Called when APNs hands us a token and again after pairing.
final class PushRegistrar {
    static let shared = PushRegistrar()

    private let tokenKey = "apnsDeviceToken"
    private init() {}

    func updateAPNsToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        registerIfPossible()
    }

    func registerIfPossible() {
        guard let apnsToken = UserDefaults.standard.string(forKey: tokenKey),
              let coupleId = KeychainService.shared.getCoupleId() else { return }
        let deviceId = KeychainService.shared.getOrCreateDeviceId()
        Task {
            do {
                _ = try await APIService.shared.registerPushToken(
                    coupleId: coupleId, deviceId: deviceId, pushToken: apnsToken
                )
            } catch {
                // Best effort — retried on next launch / pairing
                print("Push token registration failed: \(error)")
            }
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
                claimTokenIfNeeded(coupleId: saved, deviceId: deviceId)
                PushRegistrar.shared.registerIfPossible()
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    /// Devices paired before token auth existed have no token stored;
    /// claim one so the backend can enforce auth for this couple.
    private func claimTokenIfNeeded(coupleId: String, deviceId: String) {
        guard KeychainService.shared.getAuthToken() == nil else { return }
        Task {
            if let response = try? await APIService.shared.claimToken(
                coupleId: coupleId, deviceId: deviceId
            ) {
                KeychainService.shared.saveAuthToken(response.auth_token)
            }
            // 409 (already claimed) or offline: retried next launch; the
            // legacy grace path on the server keeps the app working.
        }
    }

    private func handlePaired(_ newCoupleId: String) {
        KeychainService.shared.saveCoupleId(newCoupleId)
        coupleId = newCoupleId
        deepLinkCode = nil
        PushRegistrar.shared.registerIfPossible()
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = true
        }
    }

    private func handleUnpair() {
        KeychainService.shared.deleteCoupleId()
        KeychainService.shared.deleteAuthToken()
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = false
            coupleId = ""
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handles both:
        //   loverscompass://join/ABCD1234        (custom scheme)
        //   https://<host>/join/ABCD1234          (universal link)
        let isCustomScheme = url.scheme == "loverscompass" && url.host == "join"
        let isUniversalLink = (url.scheme == "https" || url.scheme == "http")
            && url.pathComponents.count >= 2
            && url.pathComponents[1] == "join"

        guard isCustomScheme || isUniversalLink,
              let code = url.pathComponents.last,
              code.count == 8 else { return }

        if isPaired {
            // Already paired — ignore
            return
        }

        deepLinkCode = code.uppercased()
    }
}
