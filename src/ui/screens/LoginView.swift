//
//  LoginView.swift
//  Fueki Wallet
//
//  Authentication screen with social sign-on
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showBiometricPrompt = false
    @State private var isLoggingIn = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // App Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color("AccentPrimary"))

                        Text("Fueki Wallet")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))

                        Text("Your Gateway to Cryptocurrency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)

                    // Social Sign-In Buttons
                    VStack(spacing: 16) {
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                authViewModel.handleAppleSignIn(request: request)
                            },
                            onCompletion: { result in
                                Task {
                                    await authViewModel.handleAppleSignInCompletion(result: result)
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .cornerRadius(16)

                        // Google Sign In
                        SocialSignInButton(
                            title: "Continue with Google",
                            icon: "g.circle.fill",
                            backgroundColor: .white,
                            foregroundColor: .black
                        ) {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        }

                        // Facebook Sign In
                        SocialSignInButton(
                            title: "Continue with Facebook",
                            icon: "f.circle.fill",
                            backgroundColor: Color(red: 0.23, green: 0.35, blue: 0.60),
                            foregroundColor: .white
                        ) {
                            Task {
                                await authViewModel.signInWithFacebook()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .disabled(isLoggingIn)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // Biometric Sign In
                    if authViewModel.biometricType != .none {
                        Button(action: {
                            Task {
                                await authViewModel.authenticateWithBiometrics()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: authViewModel.biometricType == .faceID ? "faceid" : "touchid")
                                    .font(.title2)

                                Text("Sign in with \(authViewModel.biometricType == .faceID ? "Face ID" : "Touch ID")")
                                    .font(.headline)
                            }
                            .foregroundColor(Color("AccentPrimary"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary").opacity(0.1))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)

                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // Handle terms
                            }
                            .font(.caption)

                            Text("and")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Privacy Policy") {
                                // Handle privacy
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .overlay {
            if isLoggingIn {
                LoadingView(message: "Signing in...")
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
    }
}

// MARK: - Social Sign-In Button
struct SocialSignInButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.headline)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationViewModel())
}
