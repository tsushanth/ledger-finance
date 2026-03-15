//
//  Transaction.swift
//  LedgerFinance
//
//  SwiftData model for financial transactions
//

import Foundation
import SwiftData

// MARK: - Transaction Type
enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        }
    }

    var systemImage: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

// MARK: - Recurrence
enum RecurrenceFrequency: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .none: return "One-time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Transaction Model
@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var type: TransactionType
    var categoryID: UUID?
    var accountID: UUID?
    var date: Date
    var notes: String
    var tags: [String]
    var recurrence: RecurrenceFrequency
    var isRecurring: Bool
    var parentRecurringID: UUID?
    var receiptImageData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        type: TransactionType,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        date: Date = Date(),
        notes: String = "",
        tags: [String] = [],
        recurrence: RecurrenceFrequency = .none,
        isRecurring: Bool = false,
        parentRecurringID: UUID? = nil,
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = abs(amount)
        self.type = type
        self.categoryID = categoryID
        self.accountID = accountID
        self.date = date
        self.notes = notes
        self.tags = tags
        self.recurrence = recurrence
        self.isRecurring = isRecurring
        self.parentRecurringID = parentRecurringID
        self.receiptImageData = receiptImageData
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var signedAmount: Double {
        switch type {
        case .income: return amount
        case .expense: return -amount
        case .transfer: return 0
        }
    }
}

// MARK: - Sample Transactions
extension Transaction {
    static var samples: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return [
            Transaction(title: "Salary", amount: 5000, type: .income,
                       date: calendar.date(byAdding: .day, value: -1, to: now)!),
            Transaction(title: "Grocery Store", amount: 85.50, type: .expense,
                       date: calendar.date(byAdding: .day, value: -2, to: now)!),
            Transaction(title: "Netflix", amount: 15.99, type: .expense,
                       date: calendar.date(byAdding: .day, value: -3, to: now)!),
            Transaction(title: "Freelance Project", amount: 750, type: .income,
                       date: calendar.date(byAdding: .day, value: -5, to: now)!),
            Transaction(title: "Restaurant", amount: 45.20, type: .expense,
                       date: calendar.date(byAdding: .day, value: -7, to: now)!),
        ]
    }
}
