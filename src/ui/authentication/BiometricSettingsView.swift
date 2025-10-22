//
//  BiometricSettingsView.swift
//  Fueki Mobile Wallet
//
//  Biometric authentication settings view
//

import SwiftUI

struct BiometricSettingsView: View {

    @StateObject private var authService = BiometricAuthenticationService()
    @State private var showEnableConfirmation = false
    @State private var showDisableConfirmation = false
    @State private var isEnabling = false
    @State private var enableError: BiometricError?
    @State private var showError = false

    var body: some View {
        List {
            // Biometric status section
            Section {
                HStack {
                    Image(systemName: authService.availableBiometricType.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authService.availableBiometricType.displayName)
                            .font(.headline)

                        Text(biometricStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if authService.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Biometric Authentication")
            } footer: {
                if !authService.isAvailable {
                    Text("Biometric authentication is not available on this device. Please ensure Face ID or Touch ID is set up in Settings.")
                }
            }

            // Enable/Disable section
            Section {
                Toggle(isOn: Binding(
                    get: { authService.config.isEnabled },
                    set: { newValue in
                        if newValue {
                            showEnableConfirmation = true
                        } else {
                            showDisableConfirmation = true
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Enable Biometric Auth")
                    }
                }
                .disabled(!authService.isAvailable || isEnabling)
            } footer: {
                Text("Use \(authService.availableBiometricType.displayName) to secure your wallet and sign transactions.")
            }

            // Authentication requirements section
            if authService.config.isEnabled {
                Section {
                    Toggle(isOn: Binding(
                        get: { authService.config.requireForTransactions },
                        set: { authService.setRequireForTransactions($0) }
                    )) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require for Transactions")
                                Text("Authenticate before signing any transaction")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { authService.config.requireForAppLaunch },
                        set: { authService.setRequireForAppLaunch($0) }
                    )) {
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require for App Launch")
                                Text("Authenticate when opening the app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { authService.config.fallbackToPasscode },
                        set: { authService.setFallbackToPasscode($0) }
                    )) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allow Passcode Fallback")
                                Text("Use device passcode if biometric fails")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Security Settings")
                }
            }

            // Information section
            Section {
                InfoRow(
                    icon: "info.circle.fill",
                    color: .blue,
                    title: "Privacy",
                    description: "Your biometric data never leaves your device and is not stored by this app."
                )

                InfoRow(
                    icon: "shield.checkered",
                    color: .green,
                    title: "Security",
                    description: "Biometric authentication uses your device's Secure Enclave for maximum security."
                )
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Biometric Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Enable Biometric Authentication",
            isPresented: $showEnableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Enable") {
                enableBiometric()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will be prompted to authenticate with \(authService.availableBiometricType.displayName) to enable this feature.")
        }
        .confirmationDialog(
            "Disable Biometric Authentication",
            isPresented: $showDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) {
                authService.disableBiometricAuth()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to re-enable and authenticate to use biometric authentication again.")
        }
        .alert("Error", isPresented: $showError, presenting: enableError) { error in
            Button("OK", role: .cancel) { }
        } message: { error in
            if let description = error.errorDescription {
                Text(description)
            }
            if let recovery = error.recoverySuggestion {
                Text("\n\(recovery)")
            }
        }
    }

    private var biometricStatusText: String {
        if authService.isAvailable {
            return authService.config.isEnabled ? "Enabled and ready" : "Available"
        } else if !authService.isEnrolled {
            return "Not enrolled"
        } else {
            return "Not available"
        }
    }

    private func enableBiometric() {
        isEnabling = true
        enableError = nil

        Task {
            let result = await authService.enableBiometricAuth()

            await MainActor.run {
                isEnabling = false

                switch result {
                case .success:
                    break // Toggle will update automatically
                case .failure(let error):
                    enableError = error
                    showError = true
                }
            }
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct BiometricSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BiometricSettingsView()
        }
    }
}
