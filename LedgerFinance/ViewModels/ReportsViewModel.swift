//
//  ReportsViewModel.swift
//  LedgerFinance
//
//  ViewModel for financial reports and charts
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Report Period
enum ReportPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        case .year: return "This Year"
        case .custom: return "Custom"
        }
    }

    var months: Int {
        switch self {
        case .week: return 0
        case .month: return 1
        case .quarter: return 3
        case .year: return 12
        case .custom: return 1
        }
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date?
    let colorHex: String

    init(label: String, value: Double, date: Date? = nil, colorHex: String = "4A90D9") {
        self.label = label
        self.value = value
        self.date = date
        self.colorHex = colorHex
    }
}

// MARK: - Monthly Chart Data
struct MonthlyChartData: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expenses: Double
    let net: Double

    var monthLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM"
        return df.string(from: month)
    }
}

// MARK: - Reports ViewModel
@MainActor
@Observable
final class ReportsViewModel {
    // MARK: - State
    var transactions: [Transaction] = []
    var categories: [Category] = []
    var accounts: [Account] = []
    var budgets: [Budget] = []

    var selectedPeriod: ReportPeriod = .month
    var selectedDate: Date = Date()
    var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    var customEndDate: Date = Date()

    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Filtered Transactions
    var filteredTransactions: [Transaction] {
        let filter = dateFilter
        return TransactionService.shared.filter(transactions, with: filter)
    }

    private var dateFilter: TransactionFilter {
        switch selectedPeriod {
        case .week:
            let calendar = Calendar.current
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            let end = calendar.date(byAdding: .day, value: 6, to: start)!
            return TransactionFilter(startDate: start, endDate: end)
        case .month:
            return TransactionFilter.forMonth(selectedDate)
        case .quarter:
            let calendar = Calendar.current
            let month = calendar.component(.month, from: selectedDate)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: selectedDate)
            comps.month = quarterStartMonth; comps.day = 1
            let start = calendar.date(from: comps)!
            let end = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: start)!
            return TransactionFilter(startDate: start, endDate: end)
        case .year:
            return TransactionFilter.forYear(selectedDate)
        case .custom:
            return TransactionFilter(startDate: customStartDate, endDate: customEndDate)
        }
    }

    // MARK: - Summary Stats
    var totalIncome: Double {
        TransactionService.shared.totalIncome(filteredTransactions)
    }

    var totalExpenses: Double {
        TransactionService.shared.totalExpenses(filteredTransactions)
    }

    var netBalance: Double {
        totalIncome - totalExpenses
    }

    var savingsRate: Double {
        BudgetAnalytics.shared.savingsRate(transactions: filteredTransactions)
    }

    var dailyAverage: Double {
        BudgetAnalytics.shared.dailyAverageExpense(transactions: filteredTransactions)
    }

    // MARK: - Chart Data
    var categoryPieData: [ChartDataPoint] {
        let catAmounts = TransactionService.shared.spendingByCategory(filteredTransactions)
        return catAmounts.compactMap { catID, amount in
            guard let cat = categories.first(where: { $0.id == catID }) else { return nil }
            return ChartDataPoint(label: cat.name, value: amount, colorHex: cat.colorHex)
        }
        .sorted { $0.value > $1.value }
    }

    var monthlyBarData: [MonthlyChartData] {
        let monthCount = selectedPeriod == .year ? 12 : 6
        let data = TransactionService.shared.monthlyTotals(transactions: transactions, months: monthCount)
        return data.map { date, income, expenses in
            MonthlyChartData(month: date, income: income, expenses: expenses, net: income - expenses)
        }
    }

    var dailyLineData: [ChartDataPoint] {
        let filter = dateFilter
        let filtered = TransactionService.shared.filter(transactions, with: filter)
        let byDay = TransactionService.shared.transactionsByDay(filtered)

        let df = DateFormatter()
        df.dateFormat = "MM/dd"

        return byDay.map { date, txs in
            let expenses = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            return ChartDataPoint(label: df.string(from: date), value: expenses, date: date)
        }
        .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }

    var topCategorySpending: [CategorySpending] {
        BudgetAnalytics.shared.topCategories(
            transactions: filteredTransactions,
            categories: categories,
            limit: 6
        )
    }

    var spendingTrend: SpendingTrend {
        BudgetAnalytics.shared.computeSpendingTrend(transactions: transactions)
    }

    // MARK: - Export
    func exportData(format: ExportFormat) -> URL? {
        let options = ExportOptions(
            format: format,
            dateRange: buildDateRange(),
            filename: "ledger-report-\(formattedDateForFilename()).\(format.fileExtension)"
        )

        let data: Data?
        switch format {
        case .csv:
            data = ExportService.shared.exportCSV(
                transactions: filteredTransactions,
                categories: categories,
                accounts: accounts,
                options: options
            )
        case .pdf:
            let budgetSummaries = BudgetAnalytics.shared.computeBudgetSummaries(
                budgets: budgets,
                transactions: filteredTransactions
            )
            data = ExportService.shared.exportPDF(
                transactions: filteredTransactions,
                categories: categories,
                accounts: accounts,
                budgetSummaries: budgetSummaries,
                options: options
            )
        }

        guard let exportData = data else { return nil }

        AnalyticsService.shared.track(.exportCompleted(format: format.rawValue))
        return ExportService.shared.shareURL(
            for: exportData,
            filename: options.filename
        )
    }

    private func buildDateRange() -> ClosedRange<Date>? {
        switch selectedPeriod {
        case .custom:
            return customStartDate...customEndDate
        default:
            let filter = dateFilter
            guard let start = filter.startDate, let end = filter.endDate else { return nil }
            return start...end
        }
    }

    private func formattedDateForFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: selectedDate)
    }
}
