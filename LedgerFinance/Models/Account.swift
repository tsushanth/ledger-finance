//
//  Account.swift
//  LedgerFinance
//
//  SwiftData model for financial accounts
//

import Foundation
import SwiftData

// MARK: - Account Type
enum AccountType: String, Codable, CaseIterable {
    case checking = "checking"
    case savings = "savings"
    case creditCard = "creditCard"
    case cash = "cash"
    case investment = "investment"
    case loan = "loan"
    case other = "other"

    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .creditCard: return "Credit Card"
        case .cash: return "Cash"
        case .investment: return "Investment"
        case .loan: return "Loan"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .checking: return "building.columns.fill"
        case .savings: return "piggybank.fill"
        case .creditCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .loan: return "arrow.down.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var isAsset: Bool {
        switch self {
        case .checking, .savings, .cash, .investment: return true
        case .creditCard, .loan: return false
        case .other: return true
        }
    }

    var colorHex: String {
        switch self {
        case .checking: return "4A90D9"
        case .savings: return "27AE60"
        case .creditCard: return "E74C3C"
        case .cash: return "F39C12"
        case .investment: return "9B59B6"
        case .loan: return "E67E22"
        case .other: return "95A5A6"
        }
    }
}

// MARK: - Account Model
@Model
final class Account {
    var id: UUID
    var name: String
    var type: AccountType
    var balance: Double
    var currency: String
    var colorHex: String
    var icon: String
    var isDefault: Bool
    var isArchived: Bool
    var creditLimit: Double?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Double = 0.0,
        currency: String = "USD",
        colorHex: String = "",
        icon: String = "",
        isDefault: Bool = false,
        isArchived: Bool = false,
        creditLimit: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.currency = currency
        self.colorHex = colorHex.isEmpty ? type.colorHex : colorHex
        self.icon = icon.isEmpty ? type.systemImage : icon
        self.isDefault = isDefault
        self.isArchived = isArchived
        self.creditLimit = creditLimit
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: balance)) ?? "$\(balance)"
    }

    var availableCredit: Double? {
        guard type == .creditCard, let limit = creditLimit else { return nil }
        return limit + balance // balance is negative for credit card debt
    }
}

// MARK: - Sample Accounts
extension Account {
    static var samples: [Account] {
        [
            Account(name: "Main Checking", type: .checking, balance: 3250.00, isDefault: true),
            Account(name: "High-Yield Savings", type: .savings, balance: 12500.00),
            Account(name: "Visa Credit Card", type: .creditCard, balance: -850.00, creditLimit: 5000),
            Account(name: "Cash Wallet", type: .cash, balance: 120.00),
        ]
    }
}
