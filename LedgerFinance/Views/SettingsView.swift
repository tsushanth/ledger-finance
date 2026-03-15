//
//  SettingsView.swift
//  LedgerFinance
//
//  App settings and preferences
//

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(\.modelContext) private var modelContext

    @AppStorage("com.appfactory.ledgerfinance.currency") private var currency = "USD"
    @AppStorage("com.appfactory.ledgerfinance.weeklyNotif") private var weeklyNotifications = false
    @AppStorage("com.appfactory.ledgerfinance.darkMode") private var darkModePreference = "system"
    @AppStorage("com.appfactory.ledgerfinance.startOfMonth") private var startOfMonth = 1

    @State private var showPaywall: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var showCategoryManager: Bool = false
    @State private var exportURL: URL?
    @State private var notificationStatus: String = "Unknown"

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                if !premiumManager.isPremium {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade to Premium")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Unlock all features")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ledger Premium")
                                    .font(.headline)
                                Text("All features unlocked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Preferences
                Section("Preferences") {
                    Picker("Currency", selection: $currency) {
                        Text("US Dollar (USD)").tag("USD")
                        Text("Euro (EUR)").tag("EUR")
                        Text("British Pound (GBP)").tag("GBP")
                        Text("Japanese Yen (JPY)").tag("JPY")
                        Text("Canadian Dollar (CAD)").tag("CAD")
                        Text("Australian Dollar (AUD)").tag("AUD")
                    }

                    Picker("Start of Month", selection: $startOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }

                    Picker("Appearance", selection: $darkModePreference) {
                        Text("System Default").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                // Notifications
                Section("Notifications") {
                    Toggle("Weekly Summary", isOn: $weeklyNotifications)
                        .onChange(of: weeklyNotifications) { _, newValue in
                            Task {
                                if newValue {
                                    let granted = await NotificationManager.shared.requestPermission()
                                    if granted {
                                        await NotificationManager.shared.scheduleWeeklySummary()
                                    } else {
                                        weeklyNotifications = false
                                    }
                                } else {
                                    NotificationManager.shared.cancelNotification(identifier: "weekly-summary")
                                }
                            }
                        }

                    NavigationLink("Notification Permissions") {
                        NotificationSettingsView()
                    }
                }

                // Data Management
                Section("Data") {
                    NavigationLink("Manage Categories") {
                        CategoryManagerView()
                    }

                    NavigationLink("Accounts") {
                        AccountsView()
                    }

                    NavigationLink("Bill Reminders") {
                        BillRemindersView()
                    }

                    Button {
                        if premiumManager.canExportData {
                            showExportSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if !premiumManager.canExportData {
                                premiumBadge
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Purchases
                Section("Purchases") {
                    Button {
                        Task { await storeKit.restorePurchases() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                    .foregroundStyle(.blue)
                }

                // About
                Section("About") {
                    Link(destination: URL(string: "https://apps.apple.com/app/ledger-finance")!) {
                        Label("Rate Ledger", systemImage: "star")
                    }
                    Link(destination: URL(string: "mailto:support@appfactory.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://appfactory.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://appfactory.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }

                // Danger Zone
                Section("Danger Zone") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "settings")
            }
            .confirmationDialog("Export Data", isPresented: $showExportSheet) {
                Button("Export as CSV") { exportAllData(.csv) }
                Button("Export as PDF") { exportAllData(.pdf) }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: Binding(
                get: { exportURL.map { IdentifiableURL(url: $0) } },
                set: { exportURL = $0?.url }
            )) { item in
                ShareSheet(url: item.url)
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all transactions, accounts, budgets, and settings. This cannot be undone.")
            }
        }
    }

    private var premiumBadge: some View {
        Text("PREMIUM")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow.opacity(0.2))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }

    private func exportAllData(_ format: ExportFormat) {
        let descriptor = FetchDescriptor<Transaction>()
        let catDescriptor = FetchDescriptor<Category>()
        let accDescriptor = FetchDescriptor<Account>()

        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let categories = (try? modelContext.fetch(catDescriptor)) ?? []
        let accounts = (try? modelContext.fetch(accDescriptor)) ?? []

        let options = ExportOptions(format: format, filename: "ledger-all-data.\(format.fileExtension)")
        let data: Data?

        switch format {
        case .csv:
            data = ExportService.shared.exportCSV(transactions: transactions, categories: categories, accounts: accounts, options: options)
        case .pdf:
            data = ExportService.shared.exportPDF(transactions: transactions, categories: categories, accounts: accounts, options: options)
        }

        if let exportData = data {
            exportURL = ExportService.shared.shareURL(for: exportData, filename: options.filename)
        }
    }

    private func resetAllData() {
        try? modelContext.delete(model: Transaction.self)
        try? modelContext.delete(model: Account.self)
        try? modelContext.delete(model: Category.self)
        try? modelContext.delete(model: Budget.self)
        try? modelContext.delete(model: BillReminder.self)
        try? modelContext.delete(model: NetWorthItem.self)
        try? modelContext.delete(model: NetWorthSnapshot.self)

        // Reset UserDefaults
        UserDefaults.standard.removeObject(forKey: "com.appfactory.ledgerfinance.onboardingComplete")
        UserDefaults.standard.removeObject(forKey: "com.appfactory.ledgerfinance.isPremium")

        AnalyticsService.shared.track(.settingsChanged(key: "reset_data"))
    }
}

// MARK: - Notification Settings
struct NotificationSettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }
            }

            Section {
                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(.blue)
            }
        }
        .navigationTitle("Notifications")
        .task {
            authStatus = await NotificationManager.shared.checkPermissionStatus()
        }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized: return "Enabled"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .secondary
        }
    }
}

// MARK: - Category Manager
struct CategoryManagerView: View {
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCategory: Bool = false

    private var expenseCategories: [Category] { categories.filter { $0.type == .expense && !$0.isArchived } }
    private var incomeCategories: [Category] { categories.filter { $0.type == .income && !$0.isArchived } }

    var body: some View {
        List {
            Section("Expense Categories") {
                ForEach(expenseCategories) { cat in
                    categoryRow(cat)
                }
                Button("Add Category") { showAddCategory = true }
                    .foregroundStyle(.blue)
            }

            Section("Income Categories") {
                ForEach(incomeCategories) { cat in
                    categoryRow(cat)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView()
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: category.colorHex).opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(Color(hex: category.colorHex))
                }
            Text(category.name)
            if category.isSystem {
                Spacer()
                Text("Default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Add Category
struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var icon: String = "tag.fill"
    @State private var colorHex: String = "4A90D9"

    private let sampleIcons = [
        "cart.fill", "car.fill", "house.fill", "heart.fill", "gamecontroller.fill",
        "airplane", "fork.knife", "graduationcap.fill", "music.note", "camera.fill",
        "dumbbell.fill", "leaf.fill", "gift.fill", "pawprint.fill", "building.2.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category Name", text: $name)
                    Picker("Type", selection: $selectedType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(sampleIcons, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color.blue.opacity(0.2) : Color(.systemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { saveCategory() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveCategory() {
        let category = Category(
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: selectedType,
            isSystem: false
        )
        modelContext.insert(category)
        dismiss()
    }
}
