import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Transaction Icon
            TransactionIcon(type: transaction.type, status: transaction.status)

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type == .sent ? "Sent" : "Received")
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text(transaction.asset)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 3, height: 3)

                    Text(formatTime(transaction.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Amount and Status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(transaction.type == .sent ? "-" : "+")
                    Text("\(transaction.amount, specifier: "%.6f")")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .sent ? .red : .green)

                StatusBadge(status: transaction.status)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Transaction Icon
struct TransactionIcon: View {
    let type: TransactionType
    let status: TransactionStatus

    var icon: String {
        switch type {
        case .sent: return "arrow.up.circle.fill"
        case .received: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch status {
        case .pending: return .orange
        case .confirmed:
            return type == .sent ? .blue : .green
        case .failed: return .red
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(color)
            )
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: TransactionStatus

    var color: Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .green
        case .failed: return .red
        }
    }

    var body: some View {
        if status != .confirmed {
            Text(status.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.1))
                )
        }
    }
}

// MARK: - Transaction Model
struct Transaction: Identifiable {
    let id = UUID()
    let type: TransactionType
    let asset: String
    let amount: Double
    let value: Double
    let fee: Double
    let from: String
    let to: String
    let hash: String
    let status: TransactionStatus
    let timestamp: Date

    static func mockTransactions() -> [Transaction] {
        [
            Transaction(
                type: .received,
                asset: "ETH",
                amount: 0.5,
                value: 1500,
                fee: 1.2,
                from: "0xabcd...1234",
                to: "0x1234...5678",
                hash: "0x9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef",
                status: .confirmed,
                timestamp: Date()
            ),
            Transaction(
                type: .sent,
                asset: "BTC",
                amount: 0.01,
                value: 450,
                fee: 2.5,
                from: "0x1234...5678",
                to: "0xefgh...9012",
                hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                status: .confirmed,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            Transaction(
                type: .sent,
                asset: "SOL",
                amount: 10,
                value: 1200,
                fee: 0.5,
                from: "0x1234...5678",
                to: "0xijkl...3456",
                hash: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef1234",
                status: .pending,
                timestamp: Date().addingTimeInterval(-1800)
            ),
            Transaction(
                type: .received,
                asset: "ADA",
                amount: 100,
                value: 65,
                fee: 0.2,
                from: "0xmnop...7890",
                to: "0x1234...5678",
                hash: "0x5678567856785678567856785678567856785678567856785678567856785678",
                status: .confirmed,
                timestamp: Date().addingTimeInterval(-86400)
            ),
            Transaction(
                type: .sent,
                asset: "DOT",
                amount: 5,
                value: 42.5,
                fee: 0.3,
                from: "0x1234...5678",
                to: "0xqrst...1111",
                hash: "0x9999999999999999999999999999999999999999999999999999999999999999",
                status: .failed,
                timestamp: Date().addingTimeInterval(-172800)
            )
        ]
    }
}

enum TransactionType {
    case sent
    case received
}

enum TransactionStatus: String {
    case pending
    case confirmed
    case failed
}

// MARK: - Preview
struct TransactionRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(Transaction.mockTransactions()) { transaction in
                TransactionRow(transaction: transaction)
            }
        }
        .padding()
    }
}
