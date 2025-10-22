//
//  TransactionAuthView.swift
//  Fueki Mobile Wallet
//
//  Transaction signing authentication view
//

import SwiftUI

struct TransactionAuthView: View {

    @StateObject private var authService = BiometricAuthenticationService()
    @Environment(\.dismiss) private var dismiss

    @State private var isAuthenticating = false
    @State private var authenticationError: BiometricError?
    @State private var showError = false

    let transaction: TransactionDetails
    let onAuthenticated: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Confirm Transaction")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Transaction details card
                    VStack(spacing: 16) {
                        // Amount
                        VStack(spacing: 4) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(transaction.amount)
                                .font(.title)
                                .fontWeight(.bold)
                        }

                        Divider()

                        // Recipient
                        TransactionDetailRow(
                            icon: "arrow.right.circle.fill",
                            label: "To",
                            value: transaction.recipient,
                            color: .blue
                        )

                        // Network fee
                        TransactionDetailRow(
                            icon: "network",
                            label: "Network Fee",
                            value: transaction.networkFee,
                            color: .orange
                        )

                        // Total
                        Divider()

                        TransactionDetailRow(
                            icon: "dollarsign.circle.fill",
                            label: "Total",
                            value: transaction.total,
                            color: .green,
                            isTotal: true
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top, 24)

                    // Security notice
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secure Transaction")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Authenticate to sign and broadcast this transaction")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Biometric authentication section
                    VStack(spacing: 16) {
                        Image(systemName: authService.availableBiometricType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .symbolEffect(.pulse, isActive: isAuthenticating)

                        Text("Authenticate with \(authService.availableBiometricType.displayName)")
                            .font(.headline)

                        Text("Confirm you want to sign this transaction")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                }
            }

            Divider()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: authenticate) {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: authService.availableBiometricType.icon)
                            Text("Authenticate & Sign")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .alert("Authentication Failed", isPresented: $showError, presenting: authenticationError) { error in
            Button("Try Again") {
                authenticate()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
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
            // Auto-trigger authentication if enabled
            if authService.config.isEnabled && authService.config.requireForTransactions {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticate()
                }
            }
        }
    }

    private func authenticate() {
        isAuthenticating = true
        authenticationError = nil

        Task {
            let result = await authService.authenticateForTransaction(amount: transaction.total)

            await MainActor.run {
                isAuthenticating = false

                switch result {
                case .success:
                    onAuthenticated()
                    dismiss()
                case .failure(let error):
                    authenticationError = error

                    // Don't show error for user cancellation
                    if case .userCancel = error {
                        dismiss()
                    } else {
                        showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct TransactionDetails {
    let amount: String
    let recipient: String
    let networkFee: String
    let total: String
}

struct TransactionDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var isTotal: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .bold : .medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Preview

struct TransactionAuthView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionAuthView(
            transaction: TransactionDetails(
                amount: "0.5 ETH",
                recipient: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                networkFee: "0.002 ETH",
                total: "0.502 ETH"
            ),
            onAuthenticated: { print("Authenticated") }
        )
    }
}
