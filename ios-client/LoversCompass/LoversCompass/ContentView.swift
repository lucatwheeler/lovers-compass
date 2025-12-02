//
//  ContentView.swift
//  LoversCompass
//
//  Created by Luca Wheeler on 12/2/25.
//

import SwiftUI

struct PairingView: View {
    let deviceIdManager: DeviceIdManager
    
    @State private var deviceId: String = ""
    @State private var coupleCodeInput: String = ""
    @State private var statusMessage: String = "Not paired yet."
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Lover's Compass")
                    .font(.largeTitle.bold())
                
                VStack(spacing: 8) {
                    Text("Your Device ID")
                        .font(.headline)
                    Text(deviceId)
                        .font(.footnote.monospaced())
                        .foregroundColor(.gray)
                        .textSelection(.enabled) // lets you copy it if needed
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button {
                        // 🔜 Here we'll call /pair with action=create
                        statusMessage = "Create couple tapped (not wired yet)."
                    } label: {
                        Text("Create Couple")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("— or —")
                        .foregroundColor(.secondary)
                    
                    TextField("Enter partner's couple code", text: $coupleCodeInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                    
                    Button {
                        // 🔜 Here we'll call /pair with action=join
                        statusMessage = "Join couple tapped (not wired yet)."
                    } label: {
                        Text("Join Couple")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .onAppear {
                deviceId = deviceIdManager.getDeviceId()
            }
        }
    }
}

#Preview {
    PairingView(deviceIdManager: DeviceIdManager())
}
