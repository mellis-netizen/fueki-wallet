//
//  BiometricAuthView.swift
//  Fueki Mobile Wallet
//
//  Main biometric authentication view
//

import SwiftUI
import LocalAuthentication

struct BiometricAuthView: View {

    @StateObject private var authService = BiometricAuthenticationService()
    @State private var isAuthenticating = false
    @State private var authenticationError: BiometricError?
    @State private var showError = false
    @State private var authenticationSuccess = false

    let reason: String
    let onSuccess: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Biometric icon
            Image(systemName: authService.availableBiometricType.icon)
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, isActive: isAuthenticating)

            // Title
            Text(authService.availableBiometricType.displayName)
                .font(.title2)
                .fontWeight(.semibold)

            // Reason
            Text(reason)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Authentication button
            Button(action: authenticate) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: authService.availableBiometricType.icon)
                        Text("Authenticate")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating || !authService.isAvailable)
            .padding(.horizontal)

            // Cancel button
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(.blue)
            .padding(.bottom)
        }
        .alert("Authentication Failed", isPresented: $showError, presenting: authenticationError) { error in
            Button("OK", role: .cancel) { }
            if let recovery = error.recoverySuggestion {
                Button("Help") {
                    // Could open settings or show help
                }
            }
        } message: { error in
            if let description = error.errorDescription {
                Text(description)
            }
            if let recovery = error.recoverySuggestion {
                Text("\n\(recovery)")
            }
        }
        .onAppear {
            // Auto-trigger authentication on appear
            if authService.isAvailable && authService.config.isEnabled {
                authenticate()
            }
        }
    }

    private func authenticate() {
        isAuthenticating = true
        authenticationError = nil

        Task {
            let result = await authService.authenticate(reason: reason)

            await MainActor.run {
                isAuthenticating = false

                switch result {
                case .success:
                    authenticationSuccess = true
                    onSuccess()
                case .failure(let error):
                    authenticationError = error

                    // Only show error if it's not a user cancellation
                    if case .userCancel = error {
                        onCancel()
                    } else {
                        showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct BiometricAuthView_Previews: PreviewProvider {
    static var previews: some View {
        BiometricAuthView(
            reason: "Authenticate to access your wallet",
            onSuccess: { print("Success") },
            onCancel: { print("Cancel") }
        )
    }
}
