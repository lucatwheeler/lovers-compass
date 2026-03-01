import SwiftUI

struct SettingsView: View {
    let coupleId: String
    let onUnpair: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showUnpairConfirmation = false
    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            List {
                // Couple Code
                Section {
                    VStack(spacing: 12) {
                        Text("Your Couple Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(coupleId)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.pink)
                            .textSelection(.enabled)

                        HStack(spacing: 16) {
                            Button {
                                UIPasteboard.general.string = coupleId
                                codeCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    codeCopied = false
                                }
                            } label: {
                                Label(
                                    codeCopied ? "Copied!" : "Copy",
                                    systemImage: codeCopied ? "checkmark" : "doc.on.doc"
                                )
                                .font(.subheadline.weight(.medium))
                            }

                            ShareLink(item: "Join me on Lover's Compass! Use code: \(coupleId)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .foregroundColor(.pink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Made with \u{1F497}")
                                .font(.subheadline)
                            Text("For the two of you, always.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Unpair
                Section {
                    Button(role: .destructive) {
                        showUnpairConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Unpair", systemImage: "heart.slash")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
            .confirmationDialog(
                "Are you sure you want to unpair?",
                isPresented: $showUnpairConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unpair", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onUnpair()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to create or join a couple again.")
            }
        }
    }
}

#Preview {
    SettingsView(coupleId: "ABCD1234", onUnpair: {})
}
