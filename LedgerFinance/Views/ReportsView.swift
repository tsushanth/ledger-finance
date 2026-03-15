//
//  ReportsView.swift
//  LedgerFinance
//
//  Financial reports with charts
//

import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    @Query private var budgets: [Budget]

    @Environment(PremiumManager.self) private var premiumManager

    @State private var selectedPeriod: ReportPeriod = .month
    @State private var selectedDate: Date = Date()
    @State private var showExportSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var exportURL: URL?
    @State private var selectedChart: ChartType = .bar

    enum ChartType: String, CaseIterable {
        case bar = "Bar"
        case pie = "Pie"
        case line = "Line"
    }

    // Reports ViewModel
    private var vm: ReportsViewModel {
        let vm = ReportsViewModel()
        vm.transactions = transactions
        vm.categories = categories
        vm.accounts = accounts
        vm.budgets = budgets
        vm.selectedPeriod = selectedPeriod
        vm.selectedDate = selectedDate
        return vm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelector

                    // Summary Cards
                    summaryCards

                    // Charts
                    chartSection

                    // Top Categories
                    topCategoriesSection

                    // Spending Trend
                    spendingTrendCard

                    // Export (Premium)
                    exportSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if premiumManager.canAccessAllReports {
                            showExportSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .confirmationDialog("Export Report", isPresented: $showExportSheet) {
                Button("Export as CSV") { exportReport(.csv) }
                Button("Export as PDF") { exportReport(.pdf) }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "reports_export")
            }
            .sheet(item: Binding(
                get: { exportURL.map { IdentifiableURL(url: $0) } },
                set: { exportURL = $0?.url }
            )) { item in
                ShareSheet(url: item.url)
            }
            .onAppear {
                AnalyticsService.shared.track(.reportViewed(type: selectedPeriod.rawValue))
            }
        }
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportPeriod.allCases.filter { $0 != .custom }, id: \.rawValue) { period in
                    Button {
                        withAnimation { selectedPeriod = period }
                    } label: {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? Color.blue : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedPeriod == period ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Summary Cards
    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(title: "Income", value: vm.totalIncome, color: .green, icon: "arrow.down.circle.fill")
            summaryCard(title: "Expenses", value: vm.totalExpenses, color: .red, icon: "arrow.up.circle.fill")
            summaryCard(title: "Net Balance", value: vm.netBalance, color: vm.netBalance >= 0 ? .blue : .red, icon: "equal.circle.fill")
            summaryCard(title: "Savings Rate", value: vm.savingsRate * 100, color: .purple, icon: "percent", isPercent: true)
        }
    }

    private func summaryCard(title: String, value: Double, color: Color, icon: String, isPercent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(isPercent ? String(format: "%.1f%%", value) : formatCurrency(value))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(value < 0 && !isPercent ? .red : .primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending Overview")
                    .font(.headline)
                Spacer()
                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(ChartType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Group {
                switch selectedChart {
                case .bar: barChart
                case .pie: pieChart
                case .line: lineChart
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var barChart: some View {
        Chart(vm.monthlyBarData) { data in
            BarMark(
                x: .value("Month", data.monthLabel),
                y: .value("Income", data.income)
            )
            .foregroundStyle(.green.opacity(0.7))

            BarMark(
                x: .value("Month", data.monthLabel),
                y: .value("Expenses", data.expenses)
            )
            .foregroundStyle(.red.opacity(0.7))
        }
    }

    private var pieChart: some View {
        Chart(vm.categoryPieData) { item in
            SectorMark(
                angle: .value("Amount", item.value),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(Color(hex: item.colorHex))
            .cornerRadius(4)
            .annotation(position: .overlay) {
                if item.value > 0 {
                    Text(item.label)
                        .font(.system(size: 8))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var lineChart: some View {
        Chart(vm.dailyLineData) { point in
            LineMark(
                x: .value("Date", point.label),
                y: .value("Amount", point.value)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", point.label),
                y: .value("Amount", point.value)
            )
            .foregroundStyle(.blue.opacity(0.1))
            .interpolationMethod(.catmullRom)
        }
    }

    // MARK: - Top Categories
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Spending Categories")
                .font(.headline)

            ForEach(vm.topCategorySpending, id: \.categoryID) { cat in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: cat.categoryColor).opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: cat.categoryIcon)
                                .font(.callout)
                                .foregroundStyle(Color(hex: cat.categoryColor))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cat.categoryName)
                            .font(.subheadline)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemFill))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: cat.categoryColor))
                                    .frame(width: geo.size.width * cat.percentage, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }

                    Text(formatCurrency(cat.amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Spending Trend
    private var spendingTrendCard: some View {
        let trend = vm.spendingTrend
        return HStack(spacing: 12) {
            Image(systemName: trend.direction == .up ? "arrow.up.circle.fill" : trend.direction == .down ? "arrow.down.circle.fill" : "equal.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(trend.isPositive ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(trend.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Compared to last period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Export Section
    private var exportSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Export Report")
                    .font(.headline)
                Spacer()
                if !premiumManager.canExportData {
                    Text("PREMIUM")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                exportButton(format: .csv)
                exportButton(format: .pdf)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func exportButton(format: ExportFormat) -> some View {
        Button {
            if premiumManager.canExportData {
                exportReport(format)
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                Image(systemName: format.systemImage)
                Text(format.rawValue.uppercased())
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(premiumManager.canExportData ? Color.blue.opacity(0.1) : Color(.systemFill))
            .foregroundStyle(premiumManager.canExportData ? .blue : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func exportReport(_ format: ExportFormat) {
        let reportsVM = ReportsViewModel()
        reportsVM.transactions = transactions
        reportsVM.categories = categories
        reportsVM.accounts = accounts
        reportsVM.budgets = budgets
        reportsVM.selectedPeriod = selectedPeriod
        reportsVM.selectedDate = selectedDate

        exportURL = reportsVM.exportData(format: format)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Helpers
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
