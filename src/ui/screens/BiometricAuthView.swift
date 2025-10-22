//
//  BiometricAuthView.swift
//  Fueki Wallet
//
//  Biometric authentication for transaction signing
//

import SwiftUI
import LocalAuthentication

struct BiometricAuthView: View {
    let transaction: PendingTransaction
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @StateObject private var authManager = BiometricAuthManager()
    @State private var showManualAuth = false

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color("AccentPrimary").opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 60))
                    .foregroundColor(Color("AccentPrimary"))
            }

            // Title and Description
            VStack(spacing: 12) {
                Text("Confirm Transaction")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))

                Text("Use \(authManager.biometricType == .faceID ? "Face ID" : "Touch ID") to authorize this transaction")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Transaction Details
            VStack(spacing: 16) {
                TransactionDetailRow(
                    label: "Amount",
                    value: "\(transaction.amount.formatted()) \(transaction.asset.symbol)",
                    valueColor: Color("TextPrimary")
                )

                TransactionDetailRow(
                    label: "To",
                    value: transaction.recipient,
                    valueColor: Color("TextPrimary")
                )

                TransactionDetailRow(
                    label: "Network Fee",
                    value: "\(transaction.fee.formatted()) \(transaction.asset.symbol)",
                    valueColor: .secondary
                )

                Divider()

                TransactionDetailRow(
                    label: "Total",
                    value: "\((transaction.amount + transaction.fee).formatted()) \(transaction.asset.symbol)",
                    valueColor: Color("AccentPrimary"),
                    isHighlighted: true
                )
            }
            .padding()
            .background(Color("CardBackground"))
            .cornerRadius(16)

            Spacer()

            // Authenticate Button
            VStack(spacing: 12) {
                Button(action: authenticate) {
                    HStack {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Authenticate with \(authManager.biometricType == .faceID ? "Face ID" : "Touch ID")")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("AccentPrimary"))
                    .cornerRadius(16)
                }
                .disabled(authManager.isAuthenticating)
                .accessibleButton(
                    label: "Authenticate with biometrics",
                    hint: "Double tap to confirm transaction"
                )

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color("BackgroundPrimary"))
        .onAppear {
            // Auto-trigger authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
        .alert("Authentication Failed", isPresented: $authManager.showError) {
            Button("Try Again") {
                authenticate()
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            Text(authManager.errorMessage)
        }
    }

    private func authenticate() {
        Task {
            let success = await authManager.authenticate(
                reason: "Confirm transaction of \(transaction.amount) \(transaction.asset.symbol)"
            )

            if success {
                onSuccess()
            }
        }
    }
}

struct TransactionDetailRow: View {
    let label: String
    let value: String
    let valueColor: Color
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundColor(isHighlighted ? Color("TextPrimary") : .secondary)

            Spacer()

            Text(value)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Biometric Auth Manager

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticating = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let context = LAContext()

    var biometricType: LABiometryType {
        context.biometryType
    }

    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async -> Bool {
        guard isBiometricAvailable else {
            errorMessage = "Biometric authentication is not available on this device"
            showError = true
            return false
        }

        isAuthenticating = true

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            isAuthenticating = false

            if success {
                AccessibilityAnnouncement.announce("Authentication successful")
            }

            return success
        } catch let error as LAError {
            isAuthenticating = false

            switch error.code {
            case .authenticationFailed:
                errorMessage = "Authentication failed. Please try again."
            case .userCancel:
                errorMessage = "Authentication was cancelled."
            case .userFallback:
                errorMessage = "Fallback authentication selected."
            case .biometryNotAvailable:
                errorMessage = "Biometric authentication is not available."
            case .biometryNotEnrolled:
                errorMessage = "No biometric data is enrolled."
            case .biometryLockout:
                errorMessage = "Biometric authentication is locked. Please use your passcode."
            default:
                errorMessage = "Authentication error: \(error.localizedDescription)"
            }

            showError = true
            AccessibilityAnnouncement.announce("Authentication failed: \(errorMessage)")
            return false
        } catch {
            isAuthenticating = false
            errorMessage = "An unexpected error occurred"
            showError = true
            return false
        }
    }
}

// MARK: - Pending Transaction Model

struct PendingTransaction {
    let asset: CryptoAsset
    let amount: Decimal
    let recipient: String
    let fee: Decimal
}

// MARK: - Preview

#Preview {
    BiometricAuthView(
        transaction: PendingTransaction(
            asset: CryptoAsset(
                id: "btc",
                name: "Bitcoin",
                symbol: "BTC",
                balance: 0.5,
                priceUSD: 45000,
                change24h: 2.5,
                icon: "bitcoinsign.circle.fill",
                color: .orange,
                blockchain: "Bitcoin"
            ),
            amount: 0.1,
            recipient: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            fee: 0.0001
        ),
        onSuccess: {},
        onCancel: {}
    )
}
