//
//  BuyCryptoView.swift
//  Fueki Wallet
//
//  Buy cryptocurrency with payment methods
//

import SwiftUI

struct BuyCryptoView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var viewModel = BuyCryptoViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var selectedAsset: CryptoAsset?
    @State private var amount = ""
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showAssetPicker = false
    @State private var showPaymentMethodPicker = false
    @State private var showKYCRequired = false
    @State private var agreedToTerms = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Buy Amount
                    VStack(alignment: .leading, spacing: 12) {
                        Text("You Pay")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        HStack(spacing: 16) {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold))
                                .frame(maxWidth: .infinity)

                            Text("USD")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .cornerRadius(16)

                        // Quick Amount Buttons
                        HStack(spacing: 12) {
                            ForEach([50, 100, 500, 1000], id: \.self) { value in
                                QuickAmountButton(amount: value) {
                                    amount = String(value)
                                }
                            }
                        }
                    }

                    // Select Cryptocurrency
                    VStack(alignment: .leading, spacing: 12) {
                        Text("You Receive")
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
                                            Text(asset.name)
                                                .font(.headline)
                                                .foregroundColor(Color("TextPrimary"))

                                            if let amountDecimal = Decimal(string: amount), amountDecimal > 0 {
                                                Text("≈ \(viewModel.calculateCryptoAmount(usd: amountDecimal, asset: asset).formatted()) \(asset.symbol)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
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

                    // Payment Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Payment Method")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        Button(action: { showPaymentMethodPicker = true }) {
                            HStack {
                                if let method = selectedPaymentMethod {
                                    HStack(spacing: 12) {
                                        Image(systemName: method.icon)
                                            .font(.title2)
                                            .foregroundColor(Color("AccentPrimary"))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(method.name)
                                                .font(.headline)
                                                .foregroundColor(Color("TextPrimary"))

                                            Text(method.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Select payment method")
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

                    // Transaction Details
                    if let asset = selectedAsset,
                       let amountDecimal = Decimal(string: amount),
                       amountDecimal > 0 {
                        VStack(spacing: 12) {
                            Divider()

                            TransactionDetailRow(
                                title: "Purchase Amount",
                                value: "$\(amountDecimal.formatted())"
                            )

                            TransactionDetailRow(
                                title: "Transaction Fee",
                                value: "$\(viewModel.calculateFee(amount: amountDecimal).formatted())"
                            )

                            Divider()

                            TransactionDetailRow(
                                title: "Total",
                                value: "$\((amountDecimal + viewModel.calculateFee(amount: amountDecimal)).formatted())",
                                isHighlighted: true
                            )
                        }
                        .padding(.vertical, 8)
                    }

                    // Terms Agreement
                    Toggle(isOn: $agreedToTerms) {
                        HStack(spacing: 4) {
                            Text("I agree to the")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Terms & Conditions") {
                                // Show terms
                            }
                            .font(.caption)
                        }
                    }
                    .tint(Color("AccentPrimary"))

                    // Buy Button
                    Button(action: {
                        Task {
                            await processPurchase()
                        }
                    }) {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }

                            Text(viewModel.isProcessing ? "Processing..." : "Buy Now")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            isValidPurchase ? Color("AccentPrimary") : Color.gray
                        )
                        .cornerRadius(16)
                    }
                    .disabled(!isValidPurchase || viewModel.isProcessing)

                    // Security Notice
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color("AccentPrimary"))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secure Payment")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextPrimary"))

                            Text("Your payment information is encrypted and secure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color("AccentPrimary").opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(16)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Buy Crypto")
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
                    assets: walletViewModel.supportedAssets,
                    selectedAsset: $selectedAsset
                )
            }
            .sheet(isPresented: $showPaymentMethodPicker) {
                PaymentMethodPickerView(
                    paymentMethods: viewModel.paymentMethods,
                    selectedMethod: $selectedPaymentMethod
                )
            }
            .alert("Verification Required", isPresented: $showKYCRequired) {
                Button("Verify Now") {
                    // Navigate to KYC
                }
                Button("Later", role: .cancel) { }
            } message: {
                Text("Complete identity verification to buy cryptocurrency")
            }
        }
    }

    private var isValidPurchase: Bool {
        guard let amountDecimal = Decimal(string: amount),
              amountDecimal >= 10,
              selectedAsset != nil,
              selectedPaymentMethod != nil,
              agreedToTerms else {
            return false
        }
        return true
    }

    private func processPurchase() async {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              let paymentMethod = selectedPaymentMethod else {
            return
        }

        // Check KYC status
        if !viewModel.isKYCVerified {
            showKYCRequired = true
            return
        }

        await viewModel.processPurchase(
            asset: asset,
            amount: amountDecimal,
            paymentMethod: paymentMethod
        )

        if viewModel.purchaseSuccess {
            dismiss()
        }
    }
}

// MARK: - Quick Amount Button
struct QuickAmountButton: View {
    let amount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("$\(amount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color("AccentPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color("AccentPrimary").opacity(0.1))
                .cornerRadius(10)
        }
    }
}

// MARK: - Transaction Detail Row
struct TransactionDetailRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundColor(isHighlighted ? Color("TextPrimary") : .secondary)

            Spacer()

            Text(value)
                .font(isHighlighted ? .headline : .subheadline)
                .foregroundColor(Color("TextPrimary"))
        }
    }
}

// MARK: - Asset Detail View
struct AssetDetailView: View {
    let asset: CryptoAsset
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Asset Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(asset.color.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: asset.icon)
                                .font(.system(size: 40))
                                .foregroundColor(asset.color)
                        }

                        Text(asset.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color("TextPrimary"))

                        Text(asset.symbol)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 24)

                    // Asset Stats
                    VStack(spacing: 16) {
                        StatRow(title: "Balance", value: "\(asset.balance.formatted()) \(asset.symbol)")
                        StatRow(title: "Value", value: "$\(asset.balanceUSD.formatted())")
                        StatRow(title: "Price", value: "$\(asset.priceUSD.formatted())")
                        StatRow(
                            title: "24h Change",
                            value: "\(asset.priceChange24h >= 0 ? "+" : "")\(asset.priceChange24h.formatted())%",
                            valueColor: asset.priceChange24h >= 0 ? .green : .red
                        )
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Asset Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var valueColor: Color = Color("TextPrimary")

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    BuyCryptoView()
        .environmentObject(WalletViewModel())
}
