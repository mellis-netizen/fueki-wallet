//
//  SellCryptoView.swift
//  Fueki Wallet
//
//  Sell cryptocurrency and cash out
//

import SwiftUI

struct SellCryptoView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var viewModel = SellCryptoViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var selectedAsset: CryptoAsset?
    @State private var amount = ""
    @State private var selectedBankAccount: BankAccount?
    @State private var showAssetPicker = false
    @State private var showBankAccountPicker = false
    @State private var agreedToTerms = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Select Asset
                    VStack(alignment: .leading, spacing: 12) {
                        Text("You Sell")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        Button(action: { showAssetPicker = true }) {
                            HStack {
                                if let asset = selectedAsset {
                                    HStack(spacing: 12) {
                                        Image(systemName: asset.icon)
                                            .font(.title2)
                                            .foregroundColor(asset.color)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(asset.symbol)
                                                .font(.headline)
                                                .foregroundColor(Color("TextPrimary"))

                                            Text("Available: \(asset.balance.formatted()) \(asset.symbol)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Select cryptocurrency")
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .background(Color("CardBackground"))
                            .cornerRadius(16)
                        }
                        .foregroundColor(Color("TextPrimary"))
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Amount")
                                .font(.headline)
                                .foregroundColor(Color("TextPrimary"))

                            Spacer()

                            if let asset = selectedAsset {
                                Button(action: { amount = asset.balance.description }) {
                                    Text("Max")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color("AccentPrimary"))
                                }
                            }
                        }

                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 32, weight: .bold))
                                    .frame(maxWidth: .infinity)

                                if let asset = selectedAsset {
                                    Text(asset.symbol)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(20)
                            .background(Color("CardBackground"))
                            .cornerRadius(16)

                            if let asset = selectedAsset,
                               let amountDecimal = Decimal(string: amount),
                               amountDecimal > 0 {
                                Text("≈ $\(viewModel.calculateUSDValue(amount: amountDecimal, asset: asset).formatted())")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Bank Account
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Deposit To")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        Button(action: { showBankAccountPicker = true }) {
                            HStack {
                                if let account = selectedBankAccount {
                                    HStack(spacing: 12) {
                                        Image(systemName: "building.columns.fill")
                                            .font(.title2)
                                            .foregroundColor(Color("AccentPrimary"))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(account.bankName)
                                                .font(.headline)
                                                .foregroundColor(Color("TextPrimary"))

                                            Text("••••\(account.lastFourDigits)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Select bank account")
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .background(Color("CardBackground"))
                            .cornerRadius(16)
                        }
                        .foregroundColor(Color("TextPrimary"))

                        Button(action: {
                            // Add new bank account
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Bank Account")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("AccentPrimary"))
                        }
                    }

                    // Transaction Summary
                    if let asset = selectedAsset,
                       let amountDecimal = Decimal(string: amount),
                       amountDecimal > 0 {
                        VStack(spacing: 12) {
                            Divider()

                            TransactionDetailRow(
                                title: "Crypto Amount",
                                value: "\(amountDecimal.formatted()) \(asset.symbol)"
                            )

                            TransactionDetailRow(
                                title: "Estimated Value",
                                value: "$\(viewModel.calculateUSDValue(amount: amountDecimal, asset: asset).formatted())"
                            )

                            TransactionDetailRow(
                                title: "Transaction Fee",
                                value: "$\(viewModel.calculateFee(usdAmount: viewModel.calculateUSDValue(amount: amountDecimal, asset: asset)).formatted())"
                            )

                            Divider()

                            let usdValue = viewModel.calculateUSDValue(amount: amountDecimal, asset: asset)
                            let fee = viewModel.calculateFee(usdAmount: usdValue)
                            TransactionDetailRow(
                                title: "You Receive",
                                value: "$\((usdValue - fee).formatted())",
                                isHighlighted: true
                            )
                        }
                        .padding(.vertical, 8)
                    }

                    // Processing Time Notice
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color("SecondaryAccent"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Processing Time")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextPrimary"))

                            Text("Funds typically arrive in 1-3 business days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color("SecondaryAccent").opacity(0.1))
                    .cornerRadius(12)

                    // Terms Agreement
                    Toggle(isOn: $agreedToTerms) {
                        HStack(spacing: 4) {
                            Text("I understand the")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("terms and fees") {
                                // Show terms
                            }
                            .font(.caption)
                        }
                    }
                    .tint(Color("AccentPrimary"))

                    // Sell Button
                    Button(action: {
                        Task {
                            await processSale()
                        }
                    }) {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }

                            Text(viewModel.isProcessing ? "Processing..." : "Sell Now")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            isValidSale ? Color("SecondaryAccent") : Color.gray
                        )
                        .cornerRadius(16)
                    }
                    .disabled(!isValidSale || viewModel.isProcessing)
                }
                .padding(16)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Sell Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAssetPicker) {
                AssetPickerView(
                    assets: walletViewModel.assets,
                    selectedAsset: $selectedAsset
                )
            }
            .sheet(isPresented: $showBankAccountPicker) {
                BankAccountPickerView(
                    bankAccounts: viewModel.bankAccounts,
                    selectedAccount: $selectedBankAccount
                )
            }
        }
    }

    private var isValidSale: Bool {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              amountDecimal > 0,
              amountDecimal <= asset.balance,
              selectedBankAccount != nil,
              agreedToTerms else {
            return false
        }
        return true
    }

    private func processSale() async {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              let bankAccount = selectedBankAccount else {
            return
        }

        await viewModel.processSale(
            asset: asset,
            amount: amountDecimal,
            bankAccount: bankAccount
        )

        if viewModel.saleSuccess {
            dismiss()
        }
    }
}

// MARK: - Payment Method Picker
struct PaymentMethodPickerView: View {
    let paymentMethods: [PaymentMethod]
    @Binding var selectedMethod: PaymentMethod?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(paymentMethods) { method in
                    Button(action: {
                        selectedMethod = method
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: method.icon)
                                .font(.title2)
                                .foregroundColor(Color("AccentPrimary"))
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(method.name)
                                    .font(.headline)
                                    .foregroundColor(Color("TextPrimary"))

                                Text(method.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedMethod?.id == method.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color("BackgroundPrimary"))
                }
            }
            .listStyle(.plain)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bank Account Picker
struct BankAccountPickerView: View {
    let bankAccounts: [BankAccount]
    @Binding var selectedAccount: BankAccount?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(bankAccounts) { account in
                    Button(action: {
                        selectedAccount = account
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "building.columns.fill")
                                .font(.title2)
                                .foregroundColor(Color("AccentPrimary"))
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.bankName)
                                    .font(.headline)
                                    .foregroundColor(Color("TextPrimary"))

                                Text("••••\(account.lastFourDigits)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedAccount?.id == account.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color("BackgroundPrimary"))
                }
            }
            .listStyle(.plain)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SellCryptoView()
        .environmentObject(WalletViewModel())
}
