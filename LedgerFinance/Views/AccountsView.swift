//
//  AccountsView.swift
//  LedgerFinance
//
//  Manage financial accounts
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Query private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var showAddAccount: Bool = false
    @State private var showPaywall: Bool = false
    @State private var accountToDelete: Account?
    @State private var showDeleteAlert: Bool = false

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    private var totalBalance: Double { activeAccounts.reduce(0) { $0 + $1.balance } }
    private var totalAssets: Double { activeAccounts.filter { $0.type.isAsset }.reduce(0) { $0 + $1.balance } }
    private var totalLiabilities: Double { abs(activeAccounts.filter { !$0.type.isAsset }.reduce(0) { $0 + $1.balance }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    accountsSummary

                    // Account Cards
                    accountsList
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if premiumManager.unlimitedAccounts || accounts.count < 4 {
                            showAddAccount = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "accounts")
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let acc = accountToDelete {
                        modelContext.delete(acc)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will not delete associated transactions.")
            }
        }
    }

    // MARK: - Summary
    private var accountsSummary: some View {
        HStack(spacing: 12) {
            summaryItem(title: "Total Balance", value: totalBalance, color: .blue)
            summaryItem(title: "Assets", value: totalAssets, color: .green)
            summaryItem(title: "Debts", value: totalLiabilities, color: .red)
        }
    }

    private func summaryItem(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(formatCurrency(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Accounts List
    private var accountsList: some View {
        VStack(spacing: 12) {
            ForEach(activeAccounts) { account in
                AccountCardView(
                    account: account,
                    transactions: transactions.filter { $0.accountID == account.id }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        accountToDelete = account
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if activeAccounts.isEmpty {
                emptyAccountsState
            }
        }
    }

    private var emptyAccountsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No accounts yet")
                .font(.headline)
            Text("Add your checking, savings, or credit card accounts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Account") {
                showAddAccount = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Account Card
struct AccountCardView: View {
    let account: Account
    let transactions: [Transaction]

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Account Icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: account.colorHex).opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: account.icon)
                            .font(.title3)
                            .foregroundStyle(Color(hex: account.colorHex))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(account.formattedBalance)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(account.balance < 0 ? .red : .primary)
                    if account.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            if let available = account.availableCredit {
                HStack {
                    Text("Available Credit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatCurrency(available))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Add Account View
struct AddAccountView: View {
    var account: Account? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedType: AccountType = .checking
    @State private var balanceText: String = ""
    @State private var currency: String = "USD"
    @State private var isDefault: Bool = false
    @State private var creditLimitText: String = ""
    @State private var notes: String = ""

    private var isEditing: Bool { account != nil }
    private var showCreditLimit: Bool { selectedType == .creditCard }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)

                    Picker("Type", selection: $selectedType) {
                        ForEach(AccountType.allCases, id: \.rawValue) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                }

                Section("Balance") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField(showCreditLimit ? "Current Balance (negative if owed)" : "Current Balance", text: $balanceText)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    if showCreditLimit {
                        HStack {
                            Text("Credit Limit")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("e.g. 5000", text: $creditLimitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("Settings") {
                    Toggle("Set as Default Account", isOn: $isDefault)
                }

                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle(isEditing ? "Edit Account" : "Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { saveAccount() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let a = account else { return }
        name = a.name
        selectedType = a.type
        balanceText = String(a.balance)
        isDefault = a.isDefault
        notes = a.notes
        if let limit = a.creditLimit {
            creditLimitText = String(limit)
        }
    }

    private func saveAccount() {
        let balance = Double(balanceText) ?? 0
        let creditLimit = Double(creditLimitText)

        if let existing = account {
            existing.name = name
            existing.type = selectedType
            existing.balance = balance
            existing.isDefault = isDefault
            existing.creditLimit = creditLimit
            existing.notes = notes
            existing.updatedAt = Date()
        } else {
            let newAccount = Account(
                name: name,
                type: selectedType,
                balance: balance,
                isDefault: isDefault,
                creditLimit: creditLimit,
                notes: notes
            )
            modelContext.insert(newAccount)
            AnalyticsService.shared.track(.accountAdded(type: selectedType.rawValue))
        }
        dismiss()
    }
}
