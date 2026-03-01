//
//  LoversCompassApp.swift
//  LoversCompass
//
//  Created by Luca Wheeler on 12/2/25.
//

import SwiftUI
import UserNotifications

@main
struct LoversCompassApp: App {
    private let deviceIdManager = DeviceIdManager()

    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView(deviceIdManager: deviceIdManager)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notification permission granted: \(granted)")
        }
    }
}

struct RootView: View {
    let deviceIdManager: DeviceIdManager
    @State private var isPaired: Bool = false
    @State private var coupleId: String = ""
    @State private var deviceId: String = ""

    var body: some View {
        Group {
            if isPaired {
                NavigationStack {
                    MainView(
                        deviceId: deviceId,
                        coupleId: coupleId,
                        onUnpair: handleUnpair
                    )
                }
            } else {
                PairingView(
                    deviceIdManager: deviceIdManager,
                    onPaired: handlePaired
                )
            }
        }
        .onAppear {
            deviceId = deviceIdManager.getDeviceId()
            if let saved = deviceIdManager.savedCoupleId {
                coupleId = saved
                isPaired = true
            }
        }
    }

    private func handlePaired(_ newCoupleId: String) {
        deviceIdManager.saveCoupleId(newCoupleId)
        coupleId = newCoupleId
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = true
        }
    }

    private func handleUnpair() {
        deviceIdManager.clearCoupleId()
        withAnimation(.easeInOut(duration: 0.4)) {
            isPaired = false
            coupleId = ""
        }
    }
}
