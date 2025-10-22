import SwiftUI

struct TransactionDetailsView: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Icon
                    TransactionStatusIcon(transaction: transaction)
                        .padding(.top, 20)

                    // Amount
                    VStack(spacing: 8) {
                        Text(transaction.type == .sent ? "-" : "+")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(transaction.type == .sent ? .red : .green)
                        +
                        Text(" \(transaction.amount, specifier: "%.6f")")
                            .font(.system(size: 42, weight: .bold))

                        Text("\(transaction.asset)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("≈ $\(transaction.value, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Details
                    VStack(spacing: 16) {
                        TransactionDetailCard {
                            VStack(spacing: 12) {
                                DetailRow(label: "Status", value: transaction.status.rawValue.capitalized)
                                Divider()
                                DetailRow(label: "Type", value: transaction.type.rawValue.capitalized)
                                Divider()
                                DetailRow(label: "Date", value: formatDate(transaction.timestamp))
                                Divider()
                                DetailRow(label: "Network Fee", value: "$\(transaction.fee, specifier: "%.2f")")
                            }
                        }

                        // Addresses
                        TransactionDetailCard {
                            VStack(alignment: .leading, spacing: 16) {
                                AddressSection(
                                    title: "From",
                                    address: transaction.from,
                                    isCurrentWallet: transaction.type == .sent
                                )

                                Divider()

                                AddressSection(
                                    title: "To",
                                    address: transaction.to,
                                    isCurrentWallet: transaction.type == .received
                                )
                            }
                        }

                        // Transaction Hash
                        TransactionDetailCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Transaction Hash")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text(transaction.hash)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                        .truncationMode(.middle)

                                    Button(action: { copyHash() }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        // Block Explorer Link
                        if transaction.status == .confirmed {
                            Link(destination: URL(string: "https://etherscan.io/tx/\(transaction.hash)")!) {
                                HStack {
                                    Text("View on Block Explorer")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemBackground))
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

    private func copyHash() {
        UIPasteboard.general.string = transaction.hash
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Transaction Status Icon
struct TransactionStatusIcon: View {
    let transaction: Transaction

    var icon: String {
        switch transaction.status {
        case .pending:
            return "clock.fill"
        case .confirmed:
            return transaction.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch transaction.status {
        case .pending:
            return .orange
        case .confirmed:
            return transaction.type == .sent ? .blue : .green
        case .failed:
            return .red
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 64))
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(
                Circle()
                    .fill(color)
            )
    }
}

// MARK: - Address Section
struct AddressSection: View {
    let title: String
    let address: String
    let isCurrentWallet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if isCurrentWallet {
                    Text("(You)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }

            HStack {
                Text(address)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button(action: { copyAddress() }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = address
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Preview
struct TransactionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionDetailsView(transaction: Transaction.mockTransactions().first!)
    }
}
