//
//  TransactionService.swift
//  LedgerFinance
//
//  Service for transaction CRUD operations and analytics
//

import Foundation
import SwiftData

// MARK: - Transaction Filter
struct TransactionFilter {
    var startDate: Date?
    var endDate: Date?
    var types: [TransactionType]?
    var categoryIDs: [UUID]?
    var accountIDs: [UUID]?
    var minAmount: Double?
    var maxAmount: Double?
    var searchText: String?
    var tags: [String]?

    static var empty: TransactionFilter { TransactionFilter() }

    static func forMonth(_ date: Date) -> TransactionFilter {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return TransactionFilter(startDate: start, endDate: end)
    }

    static func forYear(_ date: Date) -> TransactionFilter {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year], from: date))!
        let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
        return TransactionFilter(startDate: start, endDate: end)
    }
}

// MARK: - Transaction Sort
enum TransactionSort {
    case dateDescending
    case dateAscending
    case amountDescending
    case amountAscending
    case titleAscending

    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .amountDescending: return "Highest Amount"
        case .amountAscending: return "Lowest Amount"
        case .titleAscending: return "Name A-Z"
        }
    }
}

// MARK: - Transaction Service
@MainActor
final class TransactionService {
    static let shared = TransactionService()

    private init() {}

    // MARK: - Filtering & Sorting
    func filter(_ transactions: [Transaction], with filter: TransactionFilter) -> [Transaction] {
        var result = transactions

        if let startDate = filter.startDate {
            result = result.filter { $0.date >= startDate }
        }

        if let endDate = filter.endDate {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate)!
            result = result.filter { $0.date < endOfDay }
        }

        if let types = filter.types, !types.isEmpty {
            result = result.filter { types.contains($0.type) }
        }

        if let categoryIDs = filter.categoryIDs, !categoryIDs.isEmpty {
            result = result.filter { t in
                guard let catID = t.categoryID else { return false }
                return categoryIDs.contains(catID)
            }
        }

        if let accountIDs = filter.accountIDs, !accountIDs.isEmpty {
            result = result.filter { t in
                guard let accID = t.accountID else { return false }
                return accountIDs.contains(accID)
            }
        }

        if let minAmount = filter.minAmount {
            result = result.filter { $0.amount >= minAmount }
        }

        if let maxAmount = filter.maxAmount {
            result = result.filter { $0.amount <= maxAmount }
        }

        if let searchText = filter.searchText, !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lower) ||
                $0.notes.lowercased().contains(lower)
            }
        }

        if let tags = filter.tags, !tags.isEmpty {
            result = result.filter { t in
                !Set(t.tags).isDisjoint(with: Set(tags))
            }
        }

        return result
    }

    func sort(_ transactions: [Transaction], by sortOrder: TransactionSort) -> [Transaction] {
        switch sortOrder {
        case .dateDescending:
            return transactions.sorted { $0.date > $1.date }
        case .dateAscending:
            return transactions.sorted { $0.date < $1.date }
        case .amountDescending:
            return transactions.sorted { $0.amount > $1.amount }
        case .amountAscending:
            return transactions.sorted { $0.amount < $1.amount }
        case .titleAscending:
            return transactions.sorted { $0.title < $1.title }
        }
    }

    // MARK: - Analytics
    func totalIncome(_ transactions: [Transaction]) -> Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    func totalExpenses(_ transactions: [Transaction]) -> Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func netBalance(_ transactions: [Transaction]) -> Double {
        totalIncome(transactions) - totalExpenses(transactions)
    }

    func spendingByCategory(_ transactions: [Transaction]) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for t in transactions where t.type == .expense {
            if let catID = t.categoryID {
                result[catID, default: 0] += t.amount
            }
        }
        return result
    }

    func transactionsByDay(_ transactions: [Transaction]) -> [Date: [Transaction]] {
        var result: [Date: [Transaction]] = [:]
        let calendar = Calendar.current
        for t in transactions {
            let day = calendar.startOfDay(for: t.date)
            result[day, default: []].append(t)
        }
        return result
    }

    func monthlyTotals(transactions: [Transaction], months: Int = 12) -> [(Date, Double, Double)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(Date, Double, Double)] = []

        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!

            let monthTransactions = transactions.filter { $0.date >= start && $0.date < end }
            let income = totalIncome(monthTransactions)
            let expenses = totalExpenses(monthTransactions)
            result.append((start, income, expenses))
        }

        return result
    }

    func averageMonthlyExpense(transactions: [Transaction], months: Int = 6) -> Double {
        let calendar = Calendar.current
        let now = Date()
        var totals: [Double] = []

        for offset in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            let monthTx = transactions.filter { $0.date >= start && $0.date < end && $0.type == .expense }
            totals.append(monthTx.reduce(0) { $0 + $1.amount })
        }

        return totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
    }

    // MARK: - Recurring Transactions
    func generateRecurringTransaction(from original: Transaction, for date: Date) -> Transaction {
        Transaction(
            title: original.title,
            amount: original.amount,
            type: original.type,
            categoryID: original.categoryID,
            accountID: original.accountID,
            date: date,
            notes: original.notes,
            tags: original.tags,
            recurrence: .none,
            isRecurring: false,
            parentRecurringID: original.id
        )
    }
}
