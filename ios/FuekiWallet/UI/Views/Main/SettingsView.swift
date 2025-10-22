import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSecuritySettings = false
    @State private var showBackup = false
    @State private var showAbout = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Wallet")
                                .font(.headline)
                            Text("0x1234...5678")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { copyAddress() }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Security Section
                Section {
                    NavigationLink(destination: SecuritySettingsView()) {
                        SettingsRow(
                            icon: "lock.shield.fill",
                            title: "Security",
                            color: .blue
                        )
                    }

                    NavigationLink(destination: BackupView()) {
                        SettingsRow(
                            icon: "arrow.clockwise.icloud.fill",
                            title: "Backup Wallet",
                            color: .green
                        )
                    }

                    NavigationLink(destination: RecoveryPhraseView()) {
                        SettingsRow(
                            icon: "key.fill",
                            title: "Show Recovery Phrase",
                            color: .orange
                        )
                    }
                } header: {
                    Text("Security")
                }

                // Preferences Section
                Section {
                    NavigationLink(destination: CurrencySettingsView()) {
                        SettingsRow(
                            icon: "dollarsign.circle.fill",
                            title: "Currency",
                            color: .green,
                            value: "USD"
                        )
                    }

                    NavigationLink(destination: LanguageSettingsView()) {
                        SettingsRow(
                            icon: "globe",
                            title: "Language",
                            color: .blue,
                            value: "English"
                        )
                    }

                    Picker(selection: $themeManager.colorScheme) {
                        Text("System").tag(nil as ColorScheme?)
                        Text("Light").tag(ColorScheme.light as ColorScheme?)
                        Text("Dark").tag(ColorScheme.dark as ColorScheme?)
                    } label: {
                        SettingsRow(
                            icon: "moon.fill",
                            title: "Appearance",
                            color: .purple
                        )
                    }
                } header: {
                    Text("Preferences")
                }

                // Network Section
                Section {
                    NavigationLink(destination: NetworkSettingsView()) {
                        SettingsRow(
                            icon: "network",
                            title: "Network",
                            color: .orange,
                            value: "Mainnet"
                        )
                    }

                    Toggle(isOn: .constant(true)) {
                        SettingsRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Auto-Update Prices",
                            color: .blue
                        )
                    }
                } header: {
                    Text("Network")
                }

                // Support Section
                Section {
                    NavigationLink(destination: HelpCenterView()) {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            title: "Help Center",
                            color: .blue
                        )
                    }

                    NavigationLink(destination: AboutView()) {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "About",
                            color: .gray
                        )
                    }

                    Link(destination: URL(string: "https://fueki.io/terms")!) {
                        SettingsRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            color: .gray
                        )
                    }

                    Link(destination: URL(string: "https://fueki.io/privacy")!) {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            title: "Privacy Policy",
                            color: .gray
                        )
                    }
                } header: {
                    Text("Support")
                }

                // Danger Zone
                Section {
                    Button(action: { showLogoutConfirmation = true }) {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Lock Wallet",
                            color: .orange
                        )
                    }

                    Button(action: { /* Reset wallet */ }) {
                        SettingsRow(
                            icon: "trash.fill",
                            title: "Reset Wallet",
                            color: .red
                        )
                    }
                } header: {
                    Text("Danger Zone")
                }

                // Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Lock Wallet", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Lock", role: .destructive) {
                    appCoordinator.lockWallet()
                }
            } message: {
                Text("Are you sure you want to lock your wallet? You'll need to authenticate to unlock it again.")
            }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = "0x1234567890abcdef"
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                )

            Text(title)
                .font(.body)

            Spacer()

            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder Views
struct BackupView: View {
    var body: some View {
        Text("Backup View")
            .navigationTitle("Backup Wallet")
    }
}

struct RecoveryPhraseView: View {
    var body: some View {
        Text("Recovery Phrase View")
            .navigationTitle("Recovery Phrase")
    }
}

struct CurrencySettingsView: View {
    var body: some View {
        Text("Currency Settings")
            .navigationTitle("Currency")
    }
}

struct LanguageSettingsView: View {
    var body: some View {
        Text("Language Settings")
            .navigationTitle("Language")
    }
}

struct NetworkSettingsView: View {
    var body: some View {
        Text("Network Settings")
            .navigationTitle("Network")
    }
}

struct HelpCenterView: View {
    var body: some View {
        Text("Help Center")
            .navigationTitle("Help Center")
    }
}

struct AboutView: View {
    var body: some View {
        Text("About Fueki Wallet")
            .navigationTitle("About")
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}
