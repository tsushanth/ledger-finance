//
//  ContentView.swift
//  LedgerFinance
//
//  Main tab bar navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showAddTransaction: Bool = false

    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.modelContext) private var modelContext

    // MARK: - Tab Enum
    enum Tab: Int, CaseIterable {
        case home = 0
        case transactions = 1
        case budget = 2
        case reports = 3
        case settings = 4

        var title: String {
            switch self {
            case .home: return "Home"
            case .transactions: return "Transactions"
            case .budget: return "Budget"
            case .reports: return "Reports"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .transactions: return "list.bullet.rectangle.fill"
            case .budget: return "chart.bar.fill"
            case .reports: return "chart.pie.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(showAddTransaction: $showAddTransaction)
                    .tag(Tab.home)
                    .tabItem {
                        Label(Tab.home.title, systemImage: Tab.home.systemImage)
                    }

                TransactionsView(showAddTransaction: $showAddTransaction)
                    .tag(Tab.transactions)
                    .tabItem {
                        Label(Tab.transactions.title, systemImage: Tab.transactions.systemImage)
                    }

                BudgetView()
                    .tag(Tab.budget)
                    .tabItem {
                        Label(Tab.budget.title, systemImage: Tab.budget.systemImage)
                    }

                ReportsView()
                    .tag(Tab.reports)
                    .tabItem {
                        Label(Tab.reports.title, systemImage: Tab.reports.systemImage)
                    }

                SettingsView()
                    .tag(Tab.settings)
                    .tabItem {
                        Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
                    }
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView()
        }
    }
}

#Preview {
    ContentView()
        .environment(PremiumManager())
        .environment(StoreKitManager())
        .modelContainer(for: [
            Transaction.self, Account.self, Category.self, Budget.self,
            BillReminder.self, NetWorthItem.self, NetWorthSnapshot.self
        ], inMemory: true)
}
