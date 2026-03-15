//
//  BudgetViewModel.swift
//  LedgerFinance
//
//  ViewModel for budget management and tracking
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BudgetViewModel {
    // MARK: - State
    var budgets: [Budget] = []
    var transactions: [Transaction] = []
    var categories: [Category] = []

    var isLoading: Bool = false
    var showAddBudget: Bool = false
    var selectedBudget: Budget?
    var errorMessage: String?

    // MARK: - Computed
    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive }
    }

    var budgetSummaries: [BudgetSummary] {
        BudgetAnalytics.shared.computeBudgetSummaries(
            budgets: activeBudgets,
            transactions: transactions
        )
    }

    var overBudgetSummaries: [BudgetSummary] {
        budgetSummaries.filter { $0.isOver }
    }

    var nearLimitSummaries: [BudgetSummary] {
        budgetSummaries.filter { $0.isNear && !$0.isOver }
    }

    var totalBudgetLimit: Double {
        activeBudgets.reduce(0) { $0 + $1.limit }
    }

    var totalBudgetSpent: Double {
        budgetSummaries.reduce(0) { $0 + $1.spent }
    }

    var totalBudgetRemaining: Double {
        max(totalBudgetLimit - totalBudgetSpent, 0)
    }

    var overallProgress: Double {
        guard totalBudgetLimit > 0 else { return 0 }
        return min(totalBudgetSpent / totalBudgetLimit, 1.0)
    }

    // MARK: - Category Helpers
    func category(for budget: Budget) -> Category? {
        guard let catID = budget.categoryID else { return nil }
        return categories.first { $0.id == catID }
    }

    func summary(for budget: Budget) -> BudgetSummary? {
        budgetSummaries.first { $0.budget.id == budget.id }
    }

    // MARK: - Spending Trend
    var spendingTrend: SpendingTrend {
        BudgetAnalytics.shared.computeSpendingTrend(transactions: transactions)
    }

    var topCategories: [CategorySpending] {
        BudgetAnalytics.shared.topCategories(
            transactions: transactions,
            categories: categories
        )
    }

    // MARK: - Alerts
    func checkBudgetAlerts() async {
        for summary in budgetSummaries where summary.isNear {
            await NotificationManager.shared.sendBudgetAlert(
                budget: summary.budget,
                spent: summary.spent
            )
        }
    }

    // MARK: - Delete
    func deleteBudget(_ budget: Budget, from context: ModelContext) {
        context.delete(budget)
        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
            budgets.remove(at: index)
        }
    }
}
