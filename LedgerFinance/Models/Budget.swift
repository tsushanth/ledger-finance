//
//  Budget.swift
//  LedgerFinance
//
//  SwiftData model for budget categories and limits
//

import Foundation
import SwiftData

// MARK: - Budget Period
enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .quarterly: return .quarter
        case .yearly: return .year
        }
    }

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        }
    }
}

// MARK: - Budget Model
@Model
final class Budget {
    var id: UUID
    var name: String
    var categoryID: UUID?
    var limit: Double
    var period: BudgetPeriod
    var startDate: Date
    var colorHex: String
    var icon: String
    var isActive: Bool
    var rolloverUnused: Bool
    var alertThreshold: Double // percentage (0.0 - 1.0) to alert at
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryID: UUID? = nil,
        limit: Double,
        period: BudgetPeriod = .monthly,
        startDate: Date = Date(),
        colorHex: String = "4A90D9",
        icon: String = "chart.bar.fill",
        isActive: Bool = true,
        rolloverUnused: Bool = false,
        alertThreshold: Double = 0.8,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.limit = limit
        self.period = period
        self.startDate = startDate
        self.colorHex = colorHex
        self.icon = icon
        self.isActive = isActive
        self.rolloverUnused = rolloverUnused
        self.alertThreshold = alertThreshold
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func progressPercentage(spent: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }

    func isOverBudget(spent: Double) -> Bool {
        spent > limit
    }

    func isNearLimit(spent: Double) -> Bool {
        progressPercentage(spent: spent) >= alertThreshold
    }

    func remaining(spent: Double) -> Double {
        max(limit - spent, 0)
    }

    var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: limit)) ?? "$\(limit)"
    }
}

// MARK: - Budget Summary
struct BudgetSummary {
    let budget: Budget
    let spent: Double
    let remaining: Double
    let progress: Double
    let isOver: Bool
    let isNear: Bool

    init(budget: Budget, spent: Double) {
        self.budget = budget
        self.spent = spent
        self.remaining = budget.remaining(spent: spent)
        self.progress = budget.progressPercentage(spent: spent)
        self.isOver = budget.isOverBudget(spent: spent)
        self.isNear = budget.isNearLimit(spent: spent)
    }
}
