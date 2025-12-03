//
//  ContentView.swift
//  LoversCompass
//
//  Created by Luca Wheeler on 12/2/25.
//

import SwiftUI

struct PairingView: View {
    let deviceIdManager: DeviceIdManager
    private let apiClient = APIClient.shared
    
    @State private var deviceId: String = ""
    @State private var coupleCodeInput: String = ""
    @State private var statusMessage: String = "Not paired yet."
    @State private var isWorking: Bool = false
    
    // Navigation state
    @State private var navigateToMain: Bool = false
    @State private var activeCoupleId: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Lover's Compass")
                    .font(.largeTitle.bold())
                
                // Device ID
                VStack(spacing: 8) {
                    Text("Your Device ID")
                        .font(.headline)
                    Text(deviceId)
                        .font(.footnote.monospaced())
                        .foregroundColor(.gray)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Pairing controls
                VStack(spacing: 12) {
                    Button {
                        Task { await handleCreateCouple() }
                    } label: {
                        Text("Create Couple")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                    
                    Text("— or —")
                        .foregroundColor(.secondary)
                    
                    TextField("Enter partner's couple code", text: $coupleCodeInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                    
                    Button {
                        Task { await handleJoinCouple() }
                    } label: {
                        Text("Join Couple")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
                .padding(.horizontal)
                
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Hidden navigation link to MainView
                NavigationLink(
                    "",
                    isActive: $navigateToMain
                ) {
                    if let coupleId = activeCoupleId {
                        MainView(deviceId: deviceId, coupleId: coupleId)
                    } else {
                        EmptyView()
                    }
                }
                .hidden()
            }
            .padding()
            .onAppear {
                deviceId = deviceIdManager.getDeviceId()
            }
        }
    }
}

// MARK: - Actions

extension PairingView {
    private func handleCreateCouple() async {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Creating couple..."

        let request = PairingRequest(
            action: "create",
            device_id: deviceId,
            couple_id: nil
        )

        do {
            let response = try await apiClient.pair(request)

            // Register this device in the database so partner can join
            // Uses placeholder coordinates until real location sharing begins
            statusMessage = "Registering device..."

            let locationRequest = LocationUpdateRequest(
                couple_id: response.couple_id,
                device_id: deviceId,
                is_sharing: false,  // Not sharing yet, just registering
                latitude: 0.0,
                longitude: 0.0
            )
            _ = try await apiClient.updateLocation(locationRequest)

            activeCoupleId = response.couple_id
            statusMessage = "Paired! Your couple code: \(response.couple_id)"
            navigateToMain = true
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isWorking = false
    }
    
    private func handleJoinCouple() async {
        guard !isWorking else { return }
        
        let trimmed = coupleCodeInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        guard !trimmed.isEmpty else {
            statusMessage = "Please enter a couple code."
            return
        }
        
        isWorking = true
        statusMessage = "Joining couple..."
        
        let request = PairingRequest(
            action: "join",
            device_id: deviceId,
            couple_id: trimmed
        )


        
        do {
            let response = try await apiClient.pair(request)
            activeCoupleId = response.couple_id
            statusMessage = "Joined couple \(response.couple_id)"
            navigateToMain = true
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isWorking = false
    }
}


// MARK: - Preview

#Preview {
    PairingView(deviceIdManager: DeviceIdManager())
}
