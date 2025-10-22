import SwiftUI

struct ActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedTransaction: Transaction?

    var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all:
            return viewModel.transactions
        case .sent:
            return viewModel.transactions.filter { $0.type == .sent }
        case .received:
            return viewModel.transactions.filter { $0.type == .received }
        case .pending:
            return viewModel.transactions.filter { $0.status == .pending }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Tabs
                    FilterTabsView(selectedFilter: $selectedFilter)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    if filteredTransactions.isEmpty {
                        EmptyActivityView()
                    } else {
                        // Transactions List
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                                    Section {
                                        ForEach(groupedTransactions[date] ?? []) { transaction in
                                            TransactionRow(transaction: transaction)
                                                .padding(.horizontal, 16)
                                                .onTapGesture {
                                                    selectedTransaction = transaction
                                                }
                                        }
                                    } header: {
                                        HStack {
                                            Text(formatDate(date))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.systemBackground))
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailsView(transaction: transaction)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadTransactions()
            }
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.timestamp)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Filter Tabs
struct FilterTabsView: View {
    @Binding var selectedFilter: TransactionFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
                )
        }
    }
}

// MARK: - Empty Activity View
struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your transaction history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Enum
enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case sent = "Sent"
    case received = "Received"
    case pending = "Pending"
}

// MARK: - View Model
class ActivityViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false

    func loadTransactions() async {
        await MainActor.run {
            transactions = Transaction.mockTransactions()
        }
    }

    func refresh() async {
        await loadTransactions()
    }
}

// MARK: - Preview
struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
