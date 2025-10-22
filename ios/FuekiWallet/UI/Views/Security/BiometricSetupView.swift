import SwiftUI
import LocalAuthentication

struct BiometricSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var biometricAuth = BiometricAuth.shared
    @State private var isEnabled = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Icon
                Image(systemName: biometricAuth.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                // Title and Description
                VStack(spacing: 12) {
                    Text(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Use \(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID") to quickly and securely access your wallet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "lock.shield.fill",
                        title: "Secure Access",
                        description: "Protect your wallet with biometric authentication"
                    )

                    FeatureRow(
                        icon: "bolt.fill",
                        title: "Quick Unlock",
                        description: "Access your wallet instantly without typing"
                    )

                    FeatureRow(
                        icon: "shield.checkmark.fill",
                        title: "Privacy First",
                        description: "Your biometric data never leaves your device"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Toggle
                Toggle(isOn: $isEnabled) {
                    Text("Enable \(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID")")
                        .font(.headline)
                }
                .padding(.horizontal, 32)
                .onChange(of: isEnabled) { newValue in
                    if newValue {
                        enrollBiometric()
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    CustomButton(
                        title: "Continue",
                        icon: "arrow.right.circle.fill",
                        style: .primary
                    ) {
                        dismiss()
                    }

                    CustomButton(
                        title: "Skip for Now",
                        style: .tertiary
                    ) {
                        dismiss()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(biometricAuth.biometricType == .faceID ? "Face ID" : "Touch ID") has been enabled")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    isEnabled = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func enrollBiometric() {
        Task {
            let success = await biometricAuth.authenticate(reason: "Enable biometric authentication")
            await MainActor.run {
                if success {
                    showSuccess = true
                } else {
                    errorMessage = "Failed to enable biometric authentication"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Biometric Auth Service
class BiometricAuth: ObservableObject {
    static let shared = BiometricAuth()

    @Published var biometricType: LABiometryType = .none
    @Published var isAvailable = false

    private let context = LAContext()

    private init() {
        checkBiometricAvailability()
    }

    private func checkBiometricAvailability() {
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            return false
        }
    }
}

// MARK: - Preview
struct BiometricSetupView_Previews: PreviewProvider {
    static var previews: some View {
        BiometricSetupView()
    }
}
