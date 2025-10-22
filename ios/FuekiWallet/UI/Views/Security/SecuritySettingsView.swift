import SwiftUI

struct SecuritySettingsView: View {
    @StateObject private var biometricAuth = BiometricAuth.shared
    @State private var biometricEnabled = true
    @State private var autoLockEnabled = true
    @State private var autoLockTime: AutoLockTime = .oneMinute
    @State private var showChangePIN = false
    @State private var showBiometricSetup = false

    var body: some View {
        List {
            // Biometric Authentication
            Section {
                if biometricAuth.isAvailable {
                    Toggle(isOn: $biometricEnabled) {
                        HStack {
                            Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID")
                        }
                    }
                    .onChange(of: biometricEnabled) { newValue in
                        if newValue {
                            showBiometricSetup = true
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Biometric Authentication")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Not Available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text("Use biometric authentication to quickly access your wallet")
            }

            // PIN Code
            Section {
                Button(action: { showChangePIN = true }) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Change PIN")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("PIN Code")
            }

            // Auto-Lock
            Section {
                Toggle(isOn: $autoLockEnabled) {
                    HStack {
                        Image(systemName: "lock.rotation")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Auto-Lock")
                    }
                }

                if autoLockEnabled {
                    Picker("Auto-Lock After", selection: $autoLockTime) {
                        ForEach(AutoLockTime.allCases, id: \.self) { time in
                            Text(time.rawValue).tag(time)
                        }
                    }
                }
            } header: {
                Text("Auto-Lock")
            } footer: {
                Text("Automatically lock the wallet after a period of inactivity")
            }

            // Transaction Security
            Section {
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Require Authentication for Transactions")
                            Text("Authenticate before sending transactions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Transaction Security")
            }

            // Privacy
            Section {
                Toggle(isOn: .constant(false)) {
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hide Balance")
                            Text("Hide balance on home screen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Screenshot Protection")
                            Text("Block screenshots on sensitive screens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Privacy")
            }

            // Security Checklist
            Section {
                NavigationLink(destination: SecurityChecklistView()) {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Security Checklist")
                            Text("Review security recommendations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showChangePIN) {
            PINSetupView()
        }
        .sheet(isPresented: $showBiometricSetup) {
            BiometricSetupView()
        }
    }
}

// MARK: - Auto Lock Time
enum AutoLockTime: String, CaseIterable {
    case immediately = "Immediately"
    case oneMinute = "1 Minute"
    case fiveMinutes = "5 Minutes"
    case fifteenMinutes = "15 Minutes"
    case never = "Never"
}

// MARK: - Security Checklist View
struct SecurityChecklistView: View {
    @State private var checklist = SecurityChecklistItem.mockItems()

    var body: some View {
        List {
            ForEach(checklist) { item in
                SecurityChecklistRow(item: item)
            }
        }
        .navigationTitle("Security Checklist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecurityChecklistRow: View {
    let item: SecurityChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isComplete ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !item.isComplete {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Security Checklist Item
struct SecurityChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    var isComplete: Bool

    static func mockItems() -> [SecurityChecklistItem] {
        [
            SecurityChecklistItem(
                title: "Backup Recovery Phrase",
                description: "Write down your recovery phrase and store it safely",
                isComplete: false
            ),
            SecurityChecklistItem(
                title: "Enable Biometric Authentication",
                description: "Use Face ID or Touch ID for quick access",
                isComplete: true
            ),
            SecurityChecklistItem(
                title: "Set Up PIN",
                description: "Create a 6-digit PIN as backup authentication",
                isComplete: true
            ),
            SecurityChecklistItem(
                title: "Verify Recovery Phrase",
                description: "Test your recovery phrase to ensure it's correct",
                isComplete: false
            ),
            SecurityChecklistItem(
                title: "Enable Auto-Lock",
                description: "Automatically lock wallet after inactivity",
                isComplete: true
            )
        ]
    }
}

// MARK: - Preview
struct SecuritySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SecuritySettingsView()
        }
    }
}
