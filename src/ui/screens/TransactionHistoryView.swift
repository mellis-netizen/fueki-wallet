//
//  TransactionHistoryView.swift
//  Fueki Wallet
//
//  Transaction history with filtering and search
//

import SwiftUI

struct TransactionHistoryView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedTransaction: Transaction?

    var filteredTransactions: [Transaction] {
        var transactions = walletViewModel.transactions

        // Apply type filter
        if selectedFilter != .all {
            transactions = transactions.filter { $0.type == selectedFilter.transactionType }
        }

        // Apply search filter
        if !searchText.isEmpty {
            transactions = transactions.filter {
                $0.assetSymbol.localizedCaseInsensitiveContains(searchText) ||
                $0.toAddress.localizedCaseInsensitiveContains(searchText) ||
                $0.fromAddress.localizedCaseInsensitiveContains(searchText)
            }
        }

        return transactions
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TransactionFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color("BackgroundPrimary"))

                Divider()

                // Transactions List
                if walletViewModel.isLoadingTransactions {
                    LoadingView(message: "Loading transactions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTransactions.isEmpty {
                    EmptyTransactionsView(filter: selectedFilter)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedTransactions, id: \.key) { group in
                            Section(header: Text(group.key)) {
                                ForEach(group.value) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .listRowBackground(Color("BackgroundPrimary"))
                                        .listRowSeparator(.hidden)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await walletViewModel.refreshTransactions()
                    }
                }
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search transactions")
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
        }
    }

    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            formatSectionHeader(date: transaction.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatSectionHeader(date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Transaction Filter
enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case sent = "Sent"
    case received = "Received"
    case bought = "Bought"
    case sold = "Sold"

    var transactionType: TransactionType? {
        switch self {
        case .all: return nil
        case .sent: return .send
        case .received: return .receive
        case .bought: return .buy
        case .sold: return .sell
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : Color("TextPrimary"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color("AccentPrimary") : Color("CardBackground"))
                )
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 16) {
            // Transaction Icon
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: transaction.type.icon)
                    .font(.title3)
                    .foregroundColor(transaction.type.color)
            }

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type.displayName)
                    .font(.headline)
                    .foregroundColor(Color("TextPrimary"))

                HStack(spacing: 4) {
                    Text(transaction.assetSymbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(transaction.status.displayName)
                        .font(.caption)
                        .foregroundColor(transaction.status.color)
                }
            }

            Spacer()

            // Amount and Time
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .send || transaction.type == .sell ? "-" : "+")\(transaction.amount.formatted()) \(transaction.assetSymbol)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.type == .send || transaction.type == .sell ? .red : .green)

                Text(transaction.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Transactions View
struct EmptyTransactionsView: View {
    let filter: TransactionFilter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No \(filter.rawValue) Transactions")
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))

            Text("Your transaction history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(transaction.status.color.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: transaction.status.icon)
                            .font(.system(size: 40))
                            .foregroundColor(transaction.status.color)
                    }
                    .padding(.top, 24)

                    // Amount
                    VStack(spacing: 8) {
                        Text("\(transaction.type == .send || transaction.type == .sell ? "-" : "+")\(transaction.amount.formatted()) \(transaction.assetSymbol)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))

                        Text("$\(transaction.amountUSD.formatted())")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    // Transaction Details
                    VStack(spacing: 16) {
                        DetailRow(title: "Status", value: transaction.status.displayName, valueColor: transaction.status.color)
                        DetailRow(title: "Type", value: transaction.type.displayName)
                        DetailRow(title: "Date", value: formatDate(transaction.timestamp))
                        DetailRow(title: "Transaction ID", value: transaction.id, isCopyable: true)

                        if !transaction.fromAddress.isEmpty {
                            DetailRow(title: "From", value: transaction.fromAddress, isCopyable: true)
                        }

                        if !transaction.toAddress.isEmpty {
                            DetailRow(title: "To", value: transaction.toAddress, isCopyable: true)
                        }

                        if let fee = transaction.networkFee {
                            DetailRow(title: "Network Fee", value: "\(fee.formatted()) \(transaction.assetSymbol)")
                        }

                        if let hash = transaction.transactionHash {
                            DetailRow(title: "Transaction Hash", value: hash, isCopyable: true)
                        }
                    }
                    .padding(.horizontal, 16)

                    // View on Explorer Button
                    if let explorerURL = transaction.explorerURL {
                        Button(action: {
                            UIApplication.shared.open(explorerURL)
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("View on Block Explorer")
                            }
                            .font(.headline)
                            .foregroundColor(Color("AccentPrimary"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color("AccentPrimary").opacity(0.1))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Transaction Details")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    var valueColor: Color = Color("TextPrimary")
    var isCopyable: Bool = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if isCopyable {
                    Button(action: {
                        UIPasteboard.general.string = value
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(showCopied ? "Copied!" : value)
                                .font(.subheadline)
                                .foregroundColor(valueColor)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(Color("AccentPrimary"))
                        }
                    }
                } else {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(valueColor)
                        .multilineTextAlignment(.trailing)
                }
            }

            Divider()
        }
    }
}

#Preview {
    TransactionHistoryView()
        .environmentObject(WalletViewModel())
}
