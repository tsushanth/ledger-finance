//
//  BudgetView.swift
//  LedgerFinance
//
//  Budget overview and management
//

import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]

    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var showAddBudget: Bool = false
    @State private var showPaywall: Bool = false
    @State private var budgetToDelete: Budget?
    @State private var showDeleteAlert: Bool = false

    private var budgetSummaries: [BudgetSummary] {
        BudgetAnalytics.shared.computeBudgetSummaries(
            budgets: budgets.filter { $0.isActive },
            transactions: transactions
        )
    }

    private var totalBudgeted: Double {
        budgets.filter { $0.isActive }.reduce(0) { $0 + $1.limit }
    }

    private var totalSpent: Double {
        budgetSummaries.reduce(0) { $0 + $1.spent }
    }

    private var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return min(totalSpent / totalBudgeted, 1.0)
    }

    private var topCategories: [CategorySpending] {
        BudgetAnalytics.shared.topCategories(
            transactions: transactions,
            categories: categories,
            limit: 5
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall Budget Card
                    overallBudgetCard

                    // Category Pie Chart
                    if !topCategories.isEmpty {
                        spendingPieChart
                    }

                    // Budget List
                    budgetListSection

                    // Premium gate for budget goals
                    if !premiumManager.canSetBudgetGoals && budgets.isEmpty {
                        budgetGoalsPremiumBanner
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddBudgetView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "budget_goals")
            }
            .alert("Delete Budget?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let b = budgetToDelete {
                        modelContext.delete(b)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Overall Budget Card
    private var overallBudgetCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Total Budget")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(totalSpent))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("of \(formatCurrency(totalBudgeted))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(overallProgress > 1.0 ? Color.red : Color.white)
                        .frame(width: geo.size.width * overallProgress, height: 8)
                        .animation(.spring(), value: overallProgress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(overallProgress * 100))% used")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(formatCurrency(max(totalBudgeted - totalSpent, 0))) left")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: overallProgress > 0.9 ? [Color.red.opacity(0.8), Color.red] : [Color.orange.opacity(0.8), Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Pie Chart
    private var spendingPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            Chart(topCategories, id: \.categoryID) { cat in
                SectorMark(
                    angle: .value("Amount", cat.amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: cat.categoryColor))
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartLegend(position: .bottom, alignment: .center)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(topCategories, id: \.categoryID) { cat in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: cat.categoryColor))
                            .frame(width: 8, height: 8)
                        Text(cat.categoryName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(formatCurrency(cat.amount))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Budget List
    private var budgetListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budgets")
                .font(.headline)

            if budgetSummaries.isEmpty {
                emptyBudgetState
            } else {
                ForEach(budgetSummaries, id: \.budget.id) { summary in
                    BudgetCardView(summary: summary, category: categories.first(where: { $0.id == summary.budget.categoryID }))
                        .contextMenu {
                            Button(role: .destructive) {
                                budgetToDelete = summary.budget
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyBudgetState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No budgets yet")
                .font(.headline)
            Text("Set spending limits by category to track your expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Budget") {
                showAddBudget = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var budgetGoalsPremiumBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading) {
                    Text("Unlock Budget Goals")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Set savings goals and track progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Budget Card
struct BudgetCardView: View {
    let summary: BudgetSummary
    let category: Category?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: category?.icon ?? summary.budget.icon)
                            .foregroundStyle(iconColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.budget.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(summary.budget.period.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(summary.spent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(summary.isOver ? .red : .primary)
                    Text("of \(formatCurrency(summary.budget.limit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * summary.progress, height: 8)
                        .animation(.spring(), value: summary.progress)
                }
            }
            .frame(height: 8)

            HStack {
                if summary.isOver {
                    Label("Over budget by \(formatCurrency(summary.spent - summary.budget.limit))", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("\(formatCurrency(summary.remaining)) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(summary.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(progressColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            if summary.isOver {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var progressColor: Color {
        if summary.isOver { return .red }
        if summary.isNear { return .orange }
        return .green
    }

    private var iconColor: Color {
        if let cat = category { return Color(hex: cat.colorHex) }
        return Color(hex: summary.budget.colorHex)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
