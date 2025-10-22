import SwiftUI

struct SendView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SendViewModel()
    @FocusState private var focusedField: SendField?

    enum SendField {
        case address, amount
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.showConfirmation {
                    TransactionConfirmationView(
                        transaction: viewModel.pendingTransaction!,
                        onConfirm: {
                            Task {
                                await viewModel.sendTransaction()
                            }
                        },
                        onCancel: {
                            viewModel.showConfirmation = false
                        }
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Asset Selector
                            AssetSelectorView(selectedAsset: $viewModel.selectedAsset)

                            // Recipient Address
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recipient Address")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    TextField("Enter address or ENS name", text: $viewModel.recipientAddress)
                                        .textFieldStyle(.plain)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .focused($focusedField, equals: .address)

                                    Button(action: { viewModel.showScanner = true }) {
                                        Image(systemName: "qrcode.viewfinder")
                                            .foregroundColor(.blue)
                                    }

                                    Button(action: { pasteAddress() }) {
                                        Image(systemName: "doc.on.clipboard")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemBackground))
                                )

                                if let error = viewModel.addressError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Amount Input
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Amount")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Balance: \(viewModel.selectedAsset?.balance ?? 0, specifier: "%.6f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    TextField("0.00", text: $viewModel.amount)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 24, weight: .semibold))
                                        .focused($focusedField, equals: .amount)

                                    Button("MAX") {
                                        viewModel.setMaxAmount()
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemBackground))
                                )

                                if let fiatValue = viewModel.fiatValue {
                                    Text("≈ $\(fiatValue, specifier: "%.2f") USD")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                if let error = viewModel.amountError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            // Fee Selector
                            FeeSelectorView(selectedSpeed: $viewModel.feeSpeed)

                            // Summary
                            TransactionSummaryCard(
                                amount: viewModel.amount,
                                fee: viewModel.estimatedFee,
                                total: viewModel.totalAmount,
                                symbol: viewModel.selectedAsset?.symbol ?? ""
                            )

                            Spacer(minLength: 40)

                            // Send Button
                            CustomButton(
                                title: "Review Transaction",
                                icon: "arrow.right.circle.fill",
                                style: .primary,
                                isLoading: viewModel.isLoading,
                                isDisabled: !viewModel.isValid
                            ) {
                                viewModel.prepareTransaction()
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showScanner) {
                QRCodeScannerView { result in
                    viewModel.recipientAddress = result
                    viewModel.showScanner = false
                }
            }
            .alert("Transaction Sent", isPresented: $viewModel.showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your transaction has been broadcast to the network")
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private func pasteAddress() {
        if let address = UIPasteboard.general.string {
            viewModel.recipientAddress = address
        }
    }
}

// MARK: - Asset Selector
struct AssetSelectorView: View {
    @Binding var selectedAsset: Asset?
    @State private var showAssetPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { showAssetPicker = true }) {
                HStack {
                    if let asset = selectedAsset {
                        AssetIcon(symbol: asset.symbol, size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(asset.symbol)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select Asset")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
            }
        }
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerView(selectedAsset: $selectedAsset)
        }
    }
}

// MARK: - Fee Selector
struct FeeSelectorView: View {
    @Binding var selectedSpeed: FeeSpeed

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Fee")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(FeeSpeed.allCases, id: \.self) { speed in
                    FeeSpeedButton(
                        speed: speed,
                        isSelected: selectedSpeed == speed
                    ) {
                        selectedSpeed = speed
                    }
                }
            }
        }
    }
}

struct FeeSpeedButton: View {
    let speed: FeeSpeed
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(speed.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(speed.time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(speed.fee, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Transaction Summary Card
struct TransactionSummaryCard: View {
    let amount: String
    let fee: Double
    let total: Double
    let symbol: String

    var body: some View {
        VStack(spacing: 12) {
            SummaryRow(label: "Amount", value: "\(amount) \(symbol)")
            SummaryRow(label: "Network Fee", value: "$\(fee, specifier: "%.2f")")
            Divider()
            SummaryRow(
                label: "Total",
                value: "$\(total, specifier: "%.2f")",
                isTotal: true
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var isTotal: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundColor(isTotal ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(isTotal ? .headline : .subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
        }
    }
}

// MARK: - Fee Speed Enum
enum FeeSpeed: String, CaseIterable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"

    var time: String {
        switch self {
        case .slow: return "~10 min"
        case .normal: return "~3 min"
        case .fast: return "~30 sec"
        }
    }

    var fee: Double {
        switch self {
        case .slow: return 0.50
        case .normal: return 1.20
        case .fast: return 2.50
        }
    }
}

// MARK: - Asset Picker
struct AssetPickerView: View {
    @Binding var selectedAsset: Asset?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(Asset.mockAssets()) { asset in
                Button(action: {
                    selectedAsset = asset
                    dismiss()
                }) {
                    AssetRow(asset: asset)
                }
            }
            .navigationTitle("Select Asset")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - View Model
class SendViewModel: ObservableObject {
    @Published var selectedAsset: Asset? = Asset.mockAssets().first
    @Published var recipientAddress = ""
    @Published var amount = ""
    @Published var feeSpeed: FeeSpeed = .normal
    @Published var isLoading = false
    @Published var showScanner = false
    @Published var showConfirmation = false
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var addressError: String?
    @Published var amountError: String?
    @Published var pendingTransaction: PendingTransaction?

    var estimatedFee: Double {
        feeSpeed.fee
    }

    var fiatValue: Double? {
        guard let doubleAmount = Double(amount),
              let asset = selectedAsset else { return nil }
        return doubleAmount * asset.price
    }

    var totalAmount: Double {
        (fiatValue ?? 0) + estimatedFee
    }

    var isValid: Bool {
        !recipientAddress.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        addressError == nil &&
        amountError == nil
    }

    func setMaxAmount() {
        if let balance = selectedAsset?.balance {
            amount = String(format: "%.6f", balance)
        }
    }

    func prepareTransaction() {
        // Validate
        validateAddress()
        validateAmount()

        guard isValid else { return }

        pendingTransaction = PendingTransaction(
            asset: selectedAsset!,
            recipient: recipientAddress,
            amount: Double(amount)!,
            fee: estimatedFee
        )
        showConfirmation = true
    }

    func sendTransaction() async {
        await MainActor.run {
            isLoading = true
        }

        // Simulate sending
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            isLoading = false
            showConfirmation = false
            showSuccess = true
        }
    }

    private func validateAddress() {
        if recipientAddress.isEmpty {
            addressError = "Address is required"
        } else if recipientAddress.count < 10 {
            addressError = "Invalid address"
        } else {
            addressError = nil
        }
    }

    private func validateAmount() {
        guard let doubleAmount = Double(amount) else {
            amountError = "Invalid amount"
            return
        }

        if doubleAmount <= 0 {
            amountError = "Amount must be greater than 0"
        } else if let balance = selectedAsset?.balance, doubleAmount > balance {
            amountError = "Insufficient balance"
        } else {
            amountError = nil
        }
    }
}

// MARK: - Pending Transaction
struct PendingTransaction {
    let asset: Asset
    let recipient: String
    let amount: Double
    let fee: Double
}

// MARK: - Preview
struct SendView_Previews: PreviewProvider {
    static var previews: some View {
        SendView()
    }
}
