import SwiftUI
import PhotosUI

/// Settings screen with couple code display, share/copy actions, about section,
/// and unpair with confirmation.
struct SettingsView: View {
    let coupleId: String
    let deviceId: String
    let onUnpair: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var photoStorage = PhotoStorage.shared
    @State private var selectedPhoto: PhotosPickerItem? = nil

    @State private var showUnpairConfirmation = false
    @State private var codeCopied = false
    @State private var isUnpairing = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let rosePink = Color(red: 1.0, green: 0.42, blue: 0.54)
    private let deepRose = Color(red: 1.0, green: 0.27, blue: 0.44)

    var body: some View {
        NavigationStack {
            List {
                coupleCodeSection
                compassPhotoSection
                privacySection
                aboutSection
                dangerSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(rosePink)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Are you sure you want to unpair?",
                isPresented: $showUnpairConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unpair", role: .destructive) {
                    Task { await performUnpair() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove both devices from the couple. You will need to create or join a couple again.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Couple Code Section

    private var coupleCodeSection: some View {
        Section {
            VStack(spacing: 14) {
                Text("Your Couple Code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Text(coupleId)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(deepRose)
                    .textSelection(.enabled)

                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = coupleId
                        withAnimation { codeCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { codeCopied = false }
                        }
                    } label: {
                        Label(
                            codeCopied ? "Copied!" : "Copy",
                            systemImage: codeCopied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(codeCopied ? .green : rosePink)
                    }

                    ShareLink(
                        item: "I want you to be my lover on Lover's Compass! 💘 Tap to join: loverscompass://join/\(coupleId)"
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(rosePink)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Privacy Section

    // MARK: - Compass Photo

    private var compassPhotoSection: some View {
        Section("Compass Photo") {
            if let image = photoStorage.partnerImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(rosePink.opacity(0.3), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locket Photo")
                            .font(.system(size: 14, weight: .medium))
                        Text("Shows on your compass face")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        photoStorage.deleteImage()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(
                    photoStorage.partnerImage == nil ? "Add Partner Photo" : "Change Photo",
                    systemImage: "camera.fill"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(rosePink)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photoStorage.saveImage(image)
                    }
                }
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            HStack {
                Label("Tracking", systemImage: "location.fill")
                Spacer()
                Text("While app is open")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            HStack {
                Label("Location Data", systemImage: "shield.lefthalf.filled")
                Spacer()
                Text("Latest only")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            HStack {
                Label("History", systemImage: "clock.fill")
                Spacer()
                Text("Never stored")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            HStack {
                Label("Third Parties", systemImage: "person.2.slash.fill")
                Spacer()
                Text("None")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(rosePink)
                    Text("Made with love, for lovers")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("For the two of you, always.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Danger Section

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showUnpairConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isUnpairing {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Label("Unpair", systemImage: "heart.slash")
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
            }
            .disabled(isUnpairing)
        }
    }

    // MARK: - Actions

    private func performUnpair() async {
        isUnpairing = true

        do {
            _ = try await APIService.shared.unpair(coupleId: coupleId, deviceId: deviceId)
        } catch {
            // Even if the server-side unpair fails (e.g., offline),
            // clear local state so the user can re-pair.
            print("Server unpair error (proceeding locally): \(error)")
        }

        await MainActor.run {
            isUnpairing = false
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onUnpair()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(coupleId: "ABCD1234", deviceId: "test-device", onUnpair: {})
}
