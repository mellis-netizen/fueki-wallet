//
//  AppLaunchAuthView.swift
//  Fueki Mobile Wallet
//
//  App launch biometric authentication view
//

import SwiftUI

struct AppLaunchAuthView: View {

    @StateObject private var authService = BiometricAuthenticationService()
    @State private var isAuthenticating = false
    @State private var authenticationError: BiometricError?
    @State private var showError = false
    @State private var authenticationAttempts = 0
    @State private var isLocked = false

    let onAuthenticated: () -> Void

    private let maxAttempts = 3

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App logo/icon
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 140, height: 140)
                    )

                // App name
                Text("Fueki Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                if isLocked {
                    // Locked state
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)

                        Text("Too Many Failed Attempts")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Please wait 30 seconds and try again")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Authentication state
                    VStack(spacing: 20) {
                        Image(systemName: authService.availableBiometricType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, isActive: isAuthenticating)

                        Text("Unlock with \(authService.availableBiometricType.displayName)")
                            .font(.headline)
                            .foregroundColor(.white)

                        if authenticationAttempts > 0 {
                            Text("\(maxAttempts - authenticationAttempts) attempts remaining")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Authenticate button
                    Button(action: authenticate) {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Image(systemName: authService.availableBiometricType.icon)
                                Text("Authenticate")
                            }
                        }
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                }

                Spacer()
            }
            .padding()
        }
        .alert("Authentication Failed", isPresented: $showError, presenting: authenticationError) { error in
            Button("Try Again") {
                authenticate()
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
            authenticate()
        }
    }

    private func authenticate() {
        guard !isLocked else { return }

        isAuthenticating = true
        authenticationError = nil

        Task {
            let result = await authService.authenticateForAppLaunch()

            await MainActor.run {
                isAuthenticating = false

                switch result {
                case .success:
                    authenticationAttempts = 0
                    onAuthenticated()
                case .failure(let error):
                    authenticationError = error

                    // Don't count user cancellation as failed attempt
                    if case .userCancel = error {
                        return
                    }

                    authenticationAttempts += 1

                    if authenticationAttempts >= maxAttempts {
                        lockApp()
                    } else {
                        showError = true
                    }
                }
            }
        }
    }

    private func lockApp() {
        isLocked = true

        // Unlock after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            authenticationAttempts = 0
            isLocked = false
        }
    }
}

// MARK: - Preview

struct AppLaunchAuthView_Previews: PreviewProvider {
    static var previews: some View {
        AppLaunchAuthView(onAuthenticated: { print("Authenticated") })
    }
}
