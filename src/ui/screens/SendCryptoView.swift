//
//  SendCryptoView.swift
//  Fueki Wallet
//
//  Send cryptocurrency with QR code scanning
//

import SwiftUI
import AVFoundation

struct SendCryptoView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var viewModel = SendCryptoViewModel()

    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var selectedAsset: CryptoAsset?
    @State private var showScanner = false
    @State private var showAssetPicker = false
    @State private var showConfirmation = false
    @State private var memo = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Asset Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Asset")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        Button(action: { showAssetPicker = true }) {
                            HStack {
                                if let asset = selectedAsset {
                                    Image(systemName: asset.icon)
                                        .foregroundColor(asset.color)
                                    Text(asset.symbol)
                                        .fontWeight(.semibold)
                                    Text("- \(asset.balance.formatted()) available")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                } else {
                                    Text("Choose an asset")
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                        }
                        .foregroundColor(Color("TextPrimary"))
                    }

                    // Recipient Address
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recipient Address")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        HStack(spacing: 12) {
                            TextField("Enter or scan address", text: $recipientAddress)
                                .textFieldStyle(.plain)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(16)
                                .background(Color("CardBackground"))
                                .cornerRadius(12)

                            Button(action: { showScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(Color("AccentPrimary"))
                                    .frame(width: 50, height: 50)
                                    .background(Color("CardBackground"))
                                    .cornerRadius(12)
                            }
                        }

                        if viewModel.isValidatingAddress {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Validating address...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if let error = viewModel.addressError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
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
                                    Text("Max: \(asset.balance.formatted()) \(asset.symbol)")
                                        .font(.caption)
                                        .foregroundColor(Color("AccentPrimary"))
                                }
                            }
                        }

                        VStack(spacing: 8) {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color("CardBackground"))
                                .cornerRadius(12)

                            if let asset = selectedAsset, let amountDecimal = Decimal(string: amount) {
                                Text("≈ $\(viewModel.calculateUSDValue(amount: amountDecimal, asset: asset).formatted())")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Memo (Optional)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Memo (Optional)")
                            .font(.headline)
                            .foregroundColor(Color("TextPrimary"))

                        TextField("Add a note", text: $memo)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(Color("CardBackground"))
                            .cornerRadius(12)
                    }

                    // Transaction Summary
                    if let asset = selectedAsset, !amount.isEmpty, !recipientAddress.isEmpty {
                        VStack(spacing: 12) {
                            Divider()

                            TransactionSummaryRow(
                                title: "Network Fee",
                                value: "\(viewModel.estimatedFee.formatted()) \(asset.symbol)",
                                subtitle: "≈ $\(viewModel.estimatedFeeUSD.formatted())"
                            )

                            if let amountDecimal = Decimal(string: amount) {
                                let total = amountDecimal + viewModel.estimatedFee
                                TransactionSummaryRow(
                                    title: "Total",
                                    value: "\(total.formatted()) \(asset.symbol)",
                                    subtitle: "≈ $\(viewModel.calculateUSDValue(amount: total, asset: asset).formatted())",
                                    isTotal: true
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Send Button
                    Button(action: {
                        showConfirmation = true
                    }) {
                        HStack {
                            if viewModel.isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }

                            Text(viewModel.isSending ? "Sending..." : "Review Transaction")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            isValidTransaction ? Color("AccentPrimary") : Color.gray
                        )
                        .cornerRadius(16)
                    }
                    .disabled(!isValidTransaction || viewModel.isSending)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Send")
            .sheet(isPresented: $showAssetPicker) {
                AssetPickerView(
                    assets: walletViewModel.assets,
                    selectedAsset: $selectedAsset
                )
            }
            .sheet(isPresented: $showScanner) {
                QRCodeScannerView(scannedCode: $recipientAddress)
            }
            .sheet(isPresented: $showConfirmation) {
                if let asset = selectedAsset, let amountDecimal = Decimal(string: amount) {
                    SendConfirmationView(
                        asset: asset,
                        amount: amountDecimal,
                        recipient: recipientAddress,
                        memo: memo,
                        networkFee: viewModel.estimatedFee,
                        onConfirm: { await sendTransaction() },
                        onCancel: { showConfirmation = false }
                    )
                }
            }
            .onChange(of: recipientAddress) { _, newValue in
                Task {
                    await viewModel.validateAddress(newValue, asset: selectedAsset)
                }
            }
            .onChange(of: selectedAsset) { _, newValue in
                Task {
                    if let asset = newValue {
                        await viewModel.estimateNetworkFee(asset: asset)
                    }
                }
            }
        }
    }

    private var isValidTransaction: Bool {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              !recipientAddress.isEmpty,
              viewModel.addressError == nil else {
            return false
        }

        return amountDecimal > 0 && amountDecimal <= asset.balance
    }

    private func sendTransaction() async {
        guard let asset = selectedAsset, let amountDecimal = Decimal(string: amount) else {
            return
        }

        await viewModel.sendTransaction(
            asset: asset,
            amount: amountDecimal,
            recipient: recipientAddress,
            memo: memo
        )

        if viewModel.transactionSuccess {
            showConfirmation = false
            // Reset form
            recipientAddress = ""
            amount = ""
            memo = ""
            selectedAsset = nil
        }
    }
}

// MARK: - Transaction Summary Row
struct TransactionSummaryRow: View {
    let title: String
    let value: String
    let subtitle: String?
    var isTotal: Bool = false

    init(title: String, value: String, subtitle: String? = nil, isTotal: Bool = false) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.isTotal = isTotal
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(isTotal ? .headline : .subheadline)
                    .foregroundColor(isTotal ? Color("TextPrimary") : .secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(isTotal ? .headline : .subheadline)
                        .foregroundColor(Color("TextPrimary"))

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if isTotal {
                Divider()
            }
        }
    }
}

// MARK: - Send Confirmation View
struct SendConfirmationView: View {
    let asset: CryptoAsset
    let amount: Decimal
    let recipient: String
    let memo: String
    let networkFee: Decimal
    let onConfirm: () async -> Void
    let onCancel: () -> Void

    @State private var isConfirming = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Asset Icon
                    ZStack {
                        Circle()
                            .fill(asset.color.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: asset.icon)
                            .font(.system(size: 40))
                            .foregroundColor(asset.color)
                    }
                    .padding(.top, 24)

                    // Amount
                    VStack(spacing: 8) {
                        Text("\(amount.formatted()) \(asset.symbol)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))

                        Text("≈ $\((amount * asset.priceUSD).formatted())")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    // Details
                    VStack(spacing: 16) {
                        ConfirmationDetailRow(title: "To", value: recipient)
                        ConfirmationDetailRow(title: "Network Fee", value: "\(networkFee.formatted()) \(asset.symbol)")

                        if !memo.isEmpty {
                            ConfirmationDetailRow(title: "Memo", value: memo)
                        }

                        Divider()

                        ConfirmationDetailRow(
                            title: "Total Amount",
                            value: "\((amount + networkFee).formatted()) \(asset.symbol)",
                            isHighlighted: true
                        )
                    }
                    .padding(.horizontal, 16)

                    // Warning
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text("Please verify the recipient address. Transactions cannot be reversed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    // Confirm Button
                    Button(action: {
                        isConfirming = true
                        Task {
                            await onConfirm()
                            isConfirming = false
                        }
                    }) {
                        HStack {
                            if isConfirming {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isConfirming ? "Confirming..." : "Confirm & Send")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("AccentPrimary"))
                        .cornerRadius(16)
                    }
                    .disabled(isConfirming)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Confirm Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isConfirming)
                }
            }
        }
    }
}

struct ConfirmationDetailRow: View {
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
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    SendCryptoView()
        .environmentObject(WalletViewModel())
}
