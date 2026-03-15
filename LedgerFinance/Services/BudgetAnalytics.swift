//
//  BudgetAnalytics.swift
//  LedgerFinance
//
//  Budget tracking, analytics, and goal computation
//

import Foundation

// MARK: - Budget Period Dates
struct BudgetPeriodDates {
    let start: Date
    let end: Date

    static func current(for period: BudgetPeriod, from startDate: Date = Date()) -> BudgetPeriodDates {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = calendar.date(byAdding: .day, value: 6, to: start)!
            return BudgetPeriodDates(start: start, end: end)

        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return BudgetPeriodDates(start: start, end: end)

        case .quarterly:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: now)
            comps.month = quarterStartMonth
            comps.day = 1
            let start = calendar.date(from: comps)!
            let end = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: start)!
            return BudgetPeriodDates(start: start, end: end)

        case .yearly:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return BudgetPeriodDates(start: start, end: end)
        }
    }
}

// MARK: - Category Spending
struct CategorySpending {
    let categoryID: UUID
    let categoryName: String
    let categoryIcon: String
    let categoryColor: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
}

// MARK: - Spending Trend
struct SpendingTrend {
    enum Direction {
        case up, down, stable
    }

    let direction: Direction
    let percentageChange: Double
    let previousAmount: Double
    let currentAmount: Double

    var isPositive: Bool {
        direction == .down
    }

    var displayText: String {
        switch direction {
        case .up:
            return "+\(String(format: "%.1f", percentageChange))% vs last period"
        case .down:
            return "-\(String(format: "%.1f", percentageChange))% vs last period"
        case .stable:
            return "No change vs last period"
        }
    }
}

// MARK: - Budget Analytics
@MainActor
final class BudgetAnalytics {
    static let shared = BudgetAnalytics()
    private init() {}

    // MARK: - Budget Progress
    func computeBudgetSummaries(
        budgets: [Budget],
        transactions: [Transaction],
        period: BudgetPeriodDates? = nil
    ) -> [BudgetSummary] {
        budgets.map { budget in
            let periodDates = period ?? BudgetPeriodDates.current(for: budget.period)
            let spent = spentAmount(
                for: budget,
                transactions: transactions,
                from: periodDates.start,
                to: periodDates.end
            )
            return BudgetSummary(budget: budget, spent: spent)
        }
    }

    private func spentAmount(
        for budget: Budget,
        transactions: [Transaction],
        from start: Date,
        to end: Date
    ) -> Double {
        let calendar = Calendar.current
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: end)!

        return transactions
            .filter { t in
                t.type == .expense &&
                t.date >= start && t.date < endOfDay &&
                (budget.categoryID == nil || t.categoryID == budget.categoryID)
            }
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Category Spending
    func topCategories(
        transactions: [Transaction],
        categories: [Category],
        limit: Int = 5
    ) -> [CategorySpending] {
        let total = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        var categoryAmounts: [UUID: (Double, Int)] = [:]
        for t in transactions where t.type == .expense {
            if let catID = t.categoryID {
                let current = categoryAmounts[catID] ?? (0, 0)
                categoryAmounts[catID] = (current.0 + t.amount, current.1 + 1)
            }
        }

        return categoryAmounts
            .compactMap { catID, data in
                guard let category = categories.first(where: { $0.id == catID }) else { return nil }
                return CategorySpending(
                    categoryID: catID,
                    categoryName: category.name,
                    categoryIcon: category.icon,
                    categoryColor: category.colorHex,
                    amount: data.0,
                    percentage: data.0 / total,
                    transactionCount: data.1
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Spending Trend
    func computeSpendingTrend(
        transactions: [Transaction],
        period: BudgetPeriod = .monthly
    ) -> SpendingTrend {
        let calendar = Calendar.current
        let now = Date()

        let (currentStart, currentEnd, previousStart, previousEnd): (Date, Date, Date, Date)

        switch period {
        case .weekly:
            let cs = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let ce = calendar.date(byAdding: .day, value: 7, to: cs)!
            let ps = calendar.date(byAdding: .weekOfYear, value: -1, to: cs)!
            let pe = cs
            (currentStart, currentEnd, previousStart, previousEnd) = (cs, ce, ps, pe)

        case .monthly:
            let cs = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let ce = calendar.date(byAdding: .month, value: 1, to: cs)!
            let ps = calendar.date(byAdding: .month, value: -1, to: cs)!
            let pe = cs
            (currentStart, currentEnd, previousStart, previousEnd) = (cs, ce, ps, pe)

        case .quarterly, .yearly:
            let cs = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let ce = calendar.date(byAdding: .year, value: 1, to: cs)!
            let ps = calendar.date(byAdding: .year, value: -1, to: cs)!
            let pe = cs
            (currentStart, currentEnd, previousStart, previousEnd) = (cs, ce, ps, pe)
        }

        let currentAmount = transactions
            .filter { $0.type == .expense && $0.date >= currentStart && $0.date < currentEnd }
            .reduce(0) { $0 + $1.amount }

        let previousAmount = transactions
            .filter { $0.type == .expense && $0.date >= previousStart && $0.date < previousEnd }
            .reduce(0) { $0 + $1.amount }

        guard previousAmount > 0 else {
            return SpendingTrend(direction: .stable, percentageChange: 0, previousAmount: 0, currentAmount: currentAmount)
        }

        let change = ((currentAmount - previousAmount) / previousAmount) * 100
        let direction: SpendingTrend.Direction = change > 1 ? .up : change < -1 ? .down : .stable

        return SpendingTrend(
            direction: direction,
            percentageChange: abs(change),
            previousAmount: previousAmount,
            currentAmount: currentAmount
        )
    }

    // MARK: - Daily Average
    func dailyAverageExpense(transactions: [Transaction], days: Int = 30) -> Double {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end)!

        let total = transactions
            .filter { $0.type == .expense && $0.date >= start && $0.date <= end }
            .reduce(0) { $0 + $1.amount }

        return total / Double(days)
    }

    // MARK: - Savings Rate
    func savingsRate(transactions: [Transaction]) -> Double {
        let income = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        guard income > 0 else { return 0 }
        return max(0, (income - expenses) / income)
    }
}
