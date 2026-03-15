//
//  TransactionsView.swift
//  LedgerFinance
//
//  Transactions list with search, filter, and sort
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Binding var showAddTransaction: Bool

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var accounts: [Account]

    @State private var searchText: String = ""
    @State private var selectedSort: TransactionSort = .dateDescending
    @State private var selectedType: TransactionType? = nil
    @State private var showFilterSheet: Bool = false
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteAlert: Bool = false
    @State private var selectedMonth: Date = Date()

    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    private var filteredTransactions: [Transaction] {
        var filter = TransactionFilter.forMonth(selectedMonth)
        if !searchText.isEmpty { filter.searchText = searchText }
        if let type = selectedType { filter.types = [type] }
        let filtered = TransactionService.shared.filter(allTransactions, with: filter)
        return TransactionService.shared.sort(filtered, by: selectedSort)
    }

    private var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var totalIncome: Double {
        TransactionService.shared.totalIncome(filteredTransactions)
    }

    private var totalExpenses: Double {
        TransactionService.shared.totalExpenses(filteredTransactions)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Selector
                monthSelector

                // Summary Bar
                summaryBar

                // Transactions List
                transactionsList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    typeFilterMenu
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        sortMenu
                        addButton
                    }
                }
            }
            .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let t = transactionToDelete {
                        withAnimation {
                            modelContext.delete(t)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Month Selector
    private var monthSelector: some View {
        HStack(spacing: 16) {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.blue)
            }

            Text(monthYearString(from: selectedMonth))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(minWidth: 120)

            Button {
                if !Calendar.current.isDateInCurrentMonth(selectedMonth) {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Calendar.current.isDateInCurrentMonth(selectedMonth) ? Color.secondary : Color.blue)
            }
            .disabled(Calendar.current.isDateInCurrentMonth(selectedMonth))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Summary Bar
    private var summaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(totalIncome))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            Spacer()

            VStack(alignment: .center, spacing: 2) {
                Text("Net")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(totalIncome - totalExpenses))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle((totalIncome - totalExpenses) >= 0 ? Color.primary : Color.red)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Expenses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(totalExpenses))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Transactions List
    private var transactionsList: some View {
        Group {
            if filteredTransactions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedTransactions, id: \.0) { date, transactions in
                        Section(header: Text(sectionDateString(date)).font(.caption).foregroundStyle(.secondary)) {
                            ForEach(transactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionRowView(transaction: transaction)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        transactionToDelete = transaction
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    NavigationLink(destination: AddTransactionView(transaction: transaction)) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No transactions" : "No results found")
                .font(.headline)
            Text(searchText.isEmpty ? "Add your first transaction to get started" : "Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button("Add Transaction") {
                    showAddTransaction = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar Items
    private var addButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.blue)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach([TransactionSort.dateDescending, .dateAscending, .amountDescending, .amountAscending], id: \.displayName) { sort in
                Button {
                    selectedSort = sort
                } label: {
                    if selectedSort.displayName == sort.displayName {
                        Label(sort.displayName, systemImage: "checkmark")
                    } else {
                        Text(sort.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(.blue)
        }
    }

    private var typeFilterMenu: some View {
        Menu {
            Button { selectedType = nil } label: {
                if selectedType == nil {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }
            ForEach(TransactionType.allCases, id: \.rawValue) { type in
                Button { selectedType = type } label: {
                    if selectedType == type {
                        Label(type.displayName, systemImage: "checkmark")
                    } else {
                        Text(type.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedType?.displayName ?? "All")
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.blue)
        }
    }

    // MARK: - Helpers
    private func monthYearString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: date)
    }

    private func sectionDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

extension Calendar {
    func isDateInCurrentMonth(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .month)
    }
}
