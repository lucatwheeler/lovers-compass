import SwiftUI

/// The initial pairing screen where users create or join a couple.
/// Features a romantic pink gradient design with smooth animations.
struct PairingView: View {
    let onPaired: (String) -> Void

    private let api = APIService.shared

    @State private var deviceId: String = ""
    @State private var coupleCodeInput: String = ""
    @State private var statusMessage: String = ""
    @State private var isWorking: Bool = false
    @State private var createdCoupleCode: String? = nil
    @State private var isPulsingHeart: Bool = false
    @State private var codeCopied: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // MARK: - Theme Colors

    private let rosePink = Color(red: 1.0, green: 0.42, blue: 0.54)     // #FF6B8A
    private let deepRose = Color(red: 1.0, green: 0.27, blue: 0.44)     // #FF4571

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 60)

                    titleSection

                    cardSection

                    deviceIdFooter

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            deviceId = KeychainService.shared.getOrCreateDeviceId()
        }
        .alert("Something Went Wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.95, blue: 0.96),
                Color(red: 1.0, green: 0.92, blue: 0.94),
                Color(red: 0.98, green: 0.88, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rosePink, deepRose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: rosePink.opacity(0.4), radius: 15, y: 5)

            Text("Love Compass")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(deepRose)

            Text("A compass that always points to your heart")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(rosePink.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Card

    private var cardSection: some View {
        VStack(spacing: 22) {
            if let code = createdCoupleCode {
                coupleCodeCard(code: code)
            }

            if createdCoupleCode == nil {
                createButton
                divider
                joinSection
            }

            if createdCoupleCode != nil {
                waitingAnimation
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(rosePink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.white.opacity(0.75))
                .shadow(color: rosePink.opacity(0.12), radius: 25, y: 12)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            Task { await handleCreateCouple() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 18))
                Text("Create Couple")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [rosePink, deepRose],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: rosePink.opacity(0.4), radius: 12, y: 4)
            )
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.6 : 1.0)
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(rosePink.opacity(0.2))
                .frame(height: 1)
            Text("or")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(rosePink.opacity(0.5))
            Rectangle()
                .fill(rosePink.opacity(0.2))
                .frame(height: 1)
        }
    }

    // MARK: - Join Section

    private var joinSection: some View {
        VStack(spacing: 14) {
            TextField("Enter couple code", text: $coupleCodeInput)
                .textFieldStyle(.plain)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(rosePink.opacity(0.25), lineWidth: 1.5)
                        )
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)

            Button {
                Task { await handleJoinCouple() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 18))
                    Text("Join Couple")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(deepRose)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(deepRose, lineWidth: 2)
                )
            }
            .disabled(isWorking || coupleCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isWorking ? 0.6 : 1.0)
        }
    }

    // MARK: - Couple Code Card

    private func coupleCodeCard(code: String) -> some View {
        VStack(spacing: 14) {
            Text("Share this code with your partner")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(rosePink.opacity(0.8))

            Text(code)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundColor(deepRose)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(rosePink.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: rosePink.opacity(0.1), radius: 8, y: 2)
                )
                .textSelection(.enabled)

            Button {
                UIPasteboard.general.string = code
                withAnimation(.easeInOut(duration: 0.2)) {
                    codeCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { codeCopied = false }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(codeCopied ? "Copied!" : "Copy Code")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(codeCopied ? Color.green : rosePink)
                )
            }
        }
    }

    // MARK: - Waiting Animation

    private var waitingAnimation: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(rosePink)
                .scaleEffect(isPulsingHeart ? 1.2 : 0.9)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isPulsingHeart
                )
                .onAppear { isPulsingHeart = true }

            Text("Waiting for your partner to join...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(rosePink.opacity(0.7))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Device ID Footer

    private var deviceIdFooter: some View {
        VStack(spacing: 4) {
            Text("Your Device ID")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(rosePink.opacity(0.35))
            Text(deviceId)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(rosePink.opacity(0.25))
                .textSelection(.enabled)
        }
        .padding(.top, 8)
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
            let response = try await api.pair(request)
            await MainActor.run {
                createdCoupleCode = response.couple_id
                statusMessage = ""
                onPaired(response.couple_id)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                statusMessage = ""
            }
        }

        await MainActor.run { isWorking = false }
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

        guard trimmed.count == 8 else {
            statusMessage = "Couple code must be exactly 8 characters."
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
            let response = try await api.pair(request)
            await MainActor.run {
                statusMessage = ""
                onPaired(response.couple_id)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                statusMessage = ""
            }
        }

        await MainActor.run { isWorking = false }
    }
}

// MARK: - Preview

#Preview {
    PairingView(onPaired: { code in
        print("Paired with code: \(code)")
    })
}
