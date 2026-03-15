//
//  HomeView.swift
//  LedgerFinance
//
//  Dashboard / home screen
//

import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Binding var showAddTransaction: Bool

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var accounts: [Account]
    @Query(sort: \BillReminder.dueDate) private var bills: [BillReminder]

    @Environment(PremiumManager.self) private var premiumManager

    private var currentMonthTransactions: [Transaction] {
        let filter = TransactionFilter.forMonth(Date())
        return TransactionService.shared.filter(allTransactions, with: filter)
    }

    private var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var monthlyIncome: Double {
        TransactionService.shared.totalIncome(currentMonthTransactions)
    }

    private var monthlyExpenses: Double {
        TransactionService.shared.totalExpenses(currentMonthTransactions)
    }

    private var upcomingBills: [BillReminder] {
        bills.filter { !$0.isPaid && $0.daysUntilDue >= 0 && $0.daysUntilDue <= 7 }
    }

    private var recentTransactions: [Transaction] {
        Array(allTransactions.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Net Balance Card
                    netBalanceCard

                    // Monthly Summary
                    monthlySummaryRow

                    // Quick Action Buttons
                    quickActions

                    // Upcoming Bills
                    if !upcomingBills.isEmpty {
                        upcomingBillsSection
                    }

                    // Recent Transactions
                    recentTransactionsSection

                    // Premium Upsell Banner
                    if !premiumManager.isPremium {
                        premiumBanner
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ledger")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AccountsView()) {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: NetWorthView()) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Net Balance Card
    private var netBalanceCard: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatCurrency(totalBalance))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(totalBalance >= 0 ? Color.primary : Color.red)

            Text(currentMonthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
    }

    private var currentMonthLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: Date())
    }

    // MARK: - Monthly Summary Row
    private var monthlySummaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Income",
                amount: monthlyIncome,
                icon: "arrow.down.circle.fill",
                color: .green
            )
            summaryCard(
                title: "Expenses",
                amount: monthlyExpenses,
                icon: "arrow.up.circle.fill",
                color: .red
            )
        }
    }

    private func summaryCard(title: String, amount: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(formatCurrency(amount))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "Add",
                icon: "plus.circle.fill",
                color: .blue
            ) {
                showAddTransaction = true
            }

            NavigationLink(destination: TransactionsView(showAddTransaction: $showAddTransaction)) {
                quickActionLabel(title: "Transactions", icon: "list.bullet", color: .purple)
            }

            NavigationLink(destination: BudgetView()) {
                quickActionLabel(title: "Budgets", icon: "chart.bar.fill", color: .orange)
            }

            NavigationLink(destination: ReportsView()) {
                quickActionLabel(title: "Reports", icon: "chart.pie.fill", color: .teal)
            }
        }
    }

    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, icon: icon, color: color)
        }
    }

    private func quickActionLabel(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Upcoming Bills
    private var upcomingBillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Upcoming Bills", destination: AnyView(BillRemindersView()))

            ForEach(upcomingBills.prefix(3)) { bill in
                billRow(bill)
            }
        }
    }

    private func billRow(_ bill: BillReminder) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: bill.colorHex).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: bill.icon)
                        .foregroundStyle(Color(hex: bill.colorHex))
                        .font(.callout)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(bill.daysUntilDue == 0 ? "Due today" : "Due in \(bill.daysUntilDue) days")
                    .font(.caption)
                    .foregroundStyle(bill.daysUntilDue <= 2 ? .red : .secondary)
            }

            Spacer()

            Text(bill.formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Transactions
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recent Transactions", destination: AnyView(TransactionsView(showAddTransaction: $showAddTransaction)))

            if recentTransactions.isEmpty {
                emptyTransactionsPlaceholder
            } else {
                ForEach(recentTransactions) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
        }
    }

    private var emptyTransactionsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No transactions yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add your first transaction") {
                showAddTransaction = true
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        NavigationLink(destination: PaywallView(source: "home_banner")) {
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Premium")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Unlimited transactions, reports & more")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers
    private func sectionHeader(title: String, destination: AnyView) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            NavigationLink(destination: destination) {
                Text("See All")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView(showAddTransaction: .constant(false))
        .environment(PremiumManager())
        .modelContainer(for: [
            Transaction.self, Account.self, Category.self, Budget.self,
            BillReminder.self, NetWorthItem.self, NetWorthSnapshot.self
        ], inMemory: true)
}
