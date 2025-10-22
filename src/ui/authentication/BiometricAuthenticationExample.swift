//
//  BiometricAuthenticationExample.swift
//  Fueki Mobile Wallet
//
//  Example usage of biometric authentication in the app
//

import SwiftUI

/// Example app integration showing how to use biometric authentication
struct BiometricAuthenticationExample: View {

    @StateObject private var authService = BiometricAuthenticationService()
    @State private var isAuthenticated = false
    @State private var showSettings = false
    @State private var showTransaction = false

    var body: some View {
        NavigationView {
            if isAuthenticated {
                authenticatedContent
            } else {
                AppLaunchAuthView {
                    isAuthenticated = true
                }
            }
        }
    }

    private var authenticatedContent: some View {
        List {
            Section("Wallet") {
                Button {
                    // Wallet action
                } label: {
                    Label("View Balance", systemImage: "dollarsign.circle.fill")
                }

                Button {
                    showTransaction = true
                } label: {
                    Label("Send Transaction", systemImage: "arrow.right.circle.fill")
                }
            }

            Section("Security") {
                NavigationLink {
                    BiometricSettingsView()
                } label: {
                    HStack {
                        Label("Biometric Authentication", systemImage: authService.availableBiometricType.icon)
                        Spacer()
                        if authService.config.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                Button {
                    isAuthenticated = false
                } label: {
                    Label("Lock Wallet", systemImage: "lock.fill")
                }
            }

            Section("Information") {
                HStack {
                    Text("Biometric Type")
                    Spacer()
                    Text(authService.availableBiometricType.displayName)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(authService.isAvailable ? "Available" : "Unavailable")
                        .foregroundColor(authService.isAvailable ? .green : .red)
                }

                HStack {
                    Text("Enabled")
                    Spacer()
                    Image(systemName: authService.config.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(authService.config.isEnabled ? .green : .red)
                }
            }
        }
        .navigationTitle("Fueki Wallet")
        .sheet(isPresented: $showTransaction) {
            TransactionAuthView(
                transaction: TransactionDetails(
                    amount: "0.5 ETH",
                    recipient: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                    networkFee: "0.002 ETH",
                    total: "0.502 ETH"
                ),
                onAuthenticated: {
                    print("Transaction authenticated and signed")
                }
            )
        }
    }
}

// MARK: - Preview

struct BiometricAuthenticationExample_Previews: PreviewProvider {
    static var previews: some View {
        BiometricAuthenticationExample()
    }
}
