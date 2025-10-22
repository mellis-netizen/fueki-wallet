import SwiftUI

struct TransactionConfirmationView: View {
    let transaction: PendingTransaction
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Confirm Transaction")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Review the details before sending")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            // Transaction Details
            ScrollView {
                VStack(spacing: 20) {
                    // Asset Info
                    TransactionDetailCard {
                        VStack(spacing: 16) {
                            HStack {
                                AssetIcon(symbol: transaction.asset.symbol, size: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.asset.name)
                                        .font(.headline)
                                    Text(transaction.asset.symbol)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            Divider()

                            DetailRow(
                                label: "Amount",
                                value: "\(transaction.amount, specifier: "%.6f") \(transaction.asset.symbol)",
                                highlighted: true
                            )

                            DetailRow(
                                label: "USD Value",
                                value: "$\(transaction.amount * transaction.asset.price, specifier: "%.2f")"
                            )
                        }
                    }

                    // Recipient Info
                    TransactionDetailCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recipient")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(transaction.recipient)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }

                    // Fee Info
                    TransactionDetailCard {
                        VStack(spacing: 12) {
                            DetailRow(
                                label: "Network Fee",
                                value: "$\(transaction.fee, specifier: "%.2f")"
                            )

                            Divider()

                            DetailRow(
                                label: "Total Amount",
                                value: "$\((transaction.amount * transaction.asset.price) + transaction.fee, specifier: "%.2f")",
                                highlighted: true
                            )
                        }
                    }

                    // Warning
                    WarningCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Transaction Cannot Be Reversed",
                        message: "Please verify all details carefully. Cryptocurrency transactions are irreversible.",
                        color: .orange
                    )
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                CustomButton(
                    title: "Confirm & Send",
                    icon: "arrow.up.circle.fill",
                    style: .primary,
                    isLoading: isLoading
                ) {
                    confirmTransaction()
                }

                CustomButton(
                    title: "Cancel",
                    style: .tertiary
                ) {
                    onCancel()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func confirmTransaction() {
        isLoading = true
        // Add haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onConfirm()
        }
    }
}

// MARK: - Transaction Detail Card
struct TransactionDetailCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack {
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    var highlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(highlighted ? .headline : .subheadline)
                .foregroundColor(highlighted ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(highlighted ? .headline : .subheadline)
                .fontWeight(highlighted ? .semibold : .regular)
        }
    }
}

// MARK: - Preview
struct TransactionConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionConfirmationView(
            transaction: PendingTransaction(
                asset: Asset.mockAssets().first!,
                recipient: "0x1234567890abcdef1234567890abcdef12345678",
                amount: 0.5,
                fee: 1.20
            ),
            onConfirm: {},
            onCancel: {}
        )
    }
}
