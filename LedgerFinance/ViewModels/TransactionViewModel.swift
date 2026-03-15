//
//  TransactionViewModel.swift
//  LedgerFinance
//
//  ViewModel for transactions list and management
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TransactionViewModel {
    // MARK: - State
    var transactions: [Transaction] = []
    var categories: [Category] = []
    var accounts: [Account] = []

    var searchText: String = ""
    var selectedFilter: TransactionFilter = .empty
    var selectedSort: TransactionSort = .dateDescending
    var selectedType: TransactionType? = nil

    var isLoading: Bool = false
    var errorMessage: String?
    var showAddTransaction: Bool = false
    var selectedTransaction: Transaction?
    var showDeleteConfirmation: Bool = false

    // MARK: - Computed
    var filteredTransactions: [Transaction] {
        var filter = selectedFilter
        filter.searchText = searchText.isEmpty ? nil : searchText
        if let type = selectedType {
            filter.types = [type]
        }

        let filtered = TransactionService.shared.filter(transactions, with: filter)
        return TransactionService.shared.sort(filtered, by: selectedSort)
    }

    var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var totalIncome: Double {
        TransactionService.shared.totalIncome(filteredTransactions)
    }

    var totalExpenses: Double {
        TransactionService.shared.totalExpenses(filteredTransactions)
    }

    var netBalance: Double {
        TransactionService.shared.netBalance(filteredTransactions)
    }

    // MARK: - Monthly Stats
    var currentMonthTransactions: [Transaction] {
        let filter = TransactionFilter.forMonth(Date())
        return TransactionService.shared.filter(transactions, with: filter)
    }

    var currentMonthIncome: Double {
        TransactionService.shared.totalIncome(currentMonthTransactions)
    }

    var currentMonthExpenses: Double {
        TransactionService.shared.totalExpenses(currentMonthTransactions)
    }

    var currentMonthNet: Double {
        currentMonthIncome - currentMonthExpenses
    }

    // MARK: - Recent Transactions
    var recentTransactions: [Transaction] {
        Array(transactions.sorted { $0.date > $1.date }.prefix(5))
    }

    // MARK: - Category Lookup
    func category(for transaction: Transaction) -> Category? {
        guard let catID = transaction.categoryID else { return nil }
        return categories.first { $0.id == catID }
    }

    func account(for transaction: Transaction) -> Account? {
        guard let accID = transaction.accountID else { return nil }
        return accounts.first { $0.id == accID }
    }

    // MARK: - Filter Helpers
    func setMonthFilter(_ date: Date) {
        selectedFilter = TransactionFilter.forMonth(date)
    }

    func setYearFilter(_ date: Date) {
        selectedFilter = TransactionFilter.forYear(date)
    }

    func clearFilter() {
        selectedFilter = .empty
        selectedType = nil
        searchText = ""
    }

    // MARK: - Delete
    func deleteTransaction(_ transaction: Transaction, from context: ModelContext) {
        context.delete(transaction)
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
        }
        AnalyticsService.shared.track(.transactionDeleted)
    }
}
