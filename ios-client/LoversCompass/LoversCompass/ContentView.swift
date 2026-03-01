//
//  ContentView.swift
//  LoversCompass
//
//  Created by Luca Wheeler on 12/2/25.
//

import SwiftUI

struct PairingView: View {
    let deviceIdManager: DeviceIdManager
    let onPaired: (String) -> Void
    private let apiClient = APIClient.shared

    @State private var deviceId: String = ""
    @State private var coupleCodeInput: String = ""
    @State private var statusMessage: String = ""
    @State private var isWorking: Bool = false
    @State private var createdCoupleCode: String? = nil
    @State private var isPulsingHeart: Bool = false
    @State private var codeCopied: Bool = false

    var body: some View {
        ZStack {
            // Pink gradient background
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.94),
                    Color(red: 0.98, green: 0.88, blue: 0.92),
                    Color(red: 0.96, green: 0.85, blue: 0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)

                    // Title
                    VStack(spacing: 8) {
                        Text("Lover's Compass")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.pink)

                        Text("Always pointing to your heart \u{1F495}")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.pink.opacity(0.7))
                    }

                    // Card container
                    VStack(spacing: 20) {
                        // Created couple code display
                        if let code = createdCoupleCode {
                            coupleCodeCard(code: code)
                        }

                        if createdCoupleCode == nil {
                            // Create button
                            Button {
                                Task { await handleCreateCouple() }
                            } label: {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                    Text("Create Couple")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink, Color(red: 0.9, green: 0.3, blue: 0.5)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .disabled(isWorking)
                            .opacity(isWorking ? 0.6 : 1.0)

                            // Divider
                            HStack {
                                Rectangle().fill(Color.pink.opacity(0.2)).frame(height: 1)
                                Text("or")
                                    .font(.subheadline)
                                    .foregroundColor(.pink.opacity(0.5))
                                Rectangle().fill(Color.pink.opacity(0.2)).frame(height: 1)
                            }

                            // Join section
                            TextField("Enter couple code", text: $coupleCodeInput)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .multilineTextAlignment(.center)

                            Button {
                                Task { await handleJoinCouple() }
                            } label: {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                    Text("Join Couple")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .foregroundColor(.pink)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.pink, lineWidth: 2)
                            )
                            .disabled(isWorking)
                            .opacity(isWorking ? 0.6 : 1.0)
                        }

                        // Waiting animation after create
                        if createdCoupleCode != nil && isWorking {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.pink)
                                    .scaleEffect(isPulsingHeart ? 1.2 : 0.9)
                                    .animation(
                                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                        value: isPulsingHeart
                                    )
                                    .onAppear { isPulsingHeart = true }

                                Text("Waiting for your partner to join...")
                                    .font(.subheadline)
                                    .foregroundColor(.pink.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                        }

                        // Status message
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundColor(statusMessage.hasPrefix("Error") ? .red : .pink.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.7))
                            .shadow(color: .pink.opacity(0.15), radius: 20, y: 10)
                    )
                    .padding(.horizontal)

                    // Device ID footer (subtle)
                    VStack(spacing: 4) {
                        Text("Your Device ID")
                            .font(.caption2)
                            .foregroundColor(.pink.opacity(0.4))
                        Text(deviceId)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.pink.opacity(0.3))
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)

                    Spacer()
                }
            }
        }
        .onAppear {
            deviceId = deviceIdManager.getDeviceId()
        }
    }

    // MARK: - Couple Code Card

    private func coupleCodeCard(code: String) -> some View {
        VStack(spacing: 12) {
            Text("Share this code with your partner")
                .font(.subheadline)
                .foregroundColor(.pink.opacity(0.7))

            Text(code)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(.pink)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.pink.opacity(0.4), lineWidth: 2)
                        )
                )
                .textSelection(.enabled)

            Button {
                UIPasteboard.general.string = code
                codeCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    codeCopied = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                    Text(codeCopied ? "Copied!" : "Copy Code")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.pink)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.pink.opacity(0.1))
                )
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

            statusMessage = "Registering device..."

            let locationRequest = LocationUpdateRequest(
                couple_id: response.couple_id,
                device_id: deviceId,
                is_sharing: false,
                latitude: 0.0,
                longitude: 0.0
            )
            _ = try await apiClient.updateLocation(locationRequest)

            createdCoupleCode = response.couple_id
            statusMessage = ""

            // Save and navigate
            onPaired(response.couple_id)
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
            statusMessage = ""
            onPaired(response.couple_id)
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isWorking = false
    }
}

// MARK: - Preview

#Preview {
    PairingView(deviceIdManager: DeviceIdManager(), onPaired: { _ in })
}
