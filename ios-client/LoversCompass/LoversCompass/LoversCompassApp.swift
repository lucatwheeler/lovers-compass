//
//  LoversCompassApp.swift
//  LoversCompass
//
//  Created by Luca Wheeler on 12/2/25.
//

import SwiftUI

@main
struct LoversCompassApp: App {
    private let deviceIdManager = DeviceIdManager()
    
    var body: some Scene {
        WindowGroup {
            PairingView(deviceIdManager: deviceIdManager)
        }
    }
}

