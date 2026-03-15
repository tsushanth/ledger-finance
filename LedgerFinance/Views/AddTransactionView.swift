//
//  AddTransactionView.swift
//  LedgerFinance
//
//  Add or edit a transaction
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    // Optional transaction for editing
    var transaction: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager

    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    @Query private var allTransactions: [Transaction]

    // Form State
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategoryID: UUID? = nil
    @State private var selectedAccountID: UUID? = nil
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var tagText: String = ""
    @State private var tags: [String] = []
    @State private var recurrence: RecurrenceFrequency = .none
    @State private var isRecurring: Bool = false

    @State private var showPaywall: Bool = false
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    private var isEditing: Bool { transaction != nil }

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Type Picker
                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.rawValue) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedType) { _, _ in
                        selectedCategoryID = nil
                    }
                }

                // Amount & Title
                Section("Details") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    TextField("Title", text: $title)
                        .autocorrectionDisabled()
                }

                // Date
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                // Category
                Section("Category") {
                    if filteredCategories.isEmpty {
                        Text("No categories available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategoryID) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(filteredCategories) { cat in
                                HStack {
                                    Image(systemName: cat.icon)
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                    Text(cat.name)
                                }
                                .tag(Optional(cat.id))
                            }
                        }
                    }
                }

                // Account
                Section("Account") {
                    if accounts.isEmpty {
                        Text("No accounts added")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: $selectedAccountID) {
                            Text("None").tag(Optional<UUID>(nil))
                            ForEach(accounts.filter { !$0.isArchived }) { acc in
                                HStack {
                                    Image(systemName: acc.type.systemImage)
                                        .foregroundStyle(Color(hex: acc.colorHex))
                                    Text(acc.name)
                                }
                                .tag(Optional(acc.id))
                            }
                        }
                    }
                }

                // Recurring (Premium)
                Section {
                    Toggle("Recurring Transaction", isOn: $isRecurring)
                        .onChange(of: isRecurring) { _, newValue in
                            if newValue && !premiumManager.canUseRecurringTransactions {
                                isRecurring = false
                                showPaywall = true
                            }
                        }

                    if isRecurring {
                        Picker("Frequency", selection: $recurrence) {
                            ForEach(RecurrenceFrequency.allCases.filter { $0 != .none }, id: \.rawValue) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recurrence")
                        if !premiumManager.canUseRecurringTransactions {
                            Spacer()
                            premiumBadge
                        }
                    }
                }

                // Notes & Tags
                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Tags") {
                    HStack {
                        TextField("Add tag...", text: $tagText)
                            .onSubmit { addTag() }
                        Button("Add") { addTag() }
                            .disabled(tagText.isEmpty)
                    }

                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Button { removeTag(tag) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") { saveTransaction() }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty || amountText.isEmpty)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "recurring_transaction")
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Helpers
    private var premiumBadge: some View {
        Text("PREMIUM")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.yellow.opacity(0.2))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }

    private func populateIfEditing() {
        guard let t = transaction else { return }
        title = t.title
        amountText = String(t.amount)
        selectedType = t.type
        selectedCategoryID = t.categoryID
        selectedAccountID = t.accountID
        date = t.date
        notes = t.notes
        tags = t.tags
        recurrence = t.recurrence
        isRecurring = t.isRecurring
    }

    private func addTag() {
        let tag = tagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        tagText = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func saveTransaction() {
        guard !title.isEmpty else {
            validationMessage = "Please enter a title."
            showValidationError = true
            return
        }

        guard let amount = Double(amountText), amount > 0 else {
            validationMessage = "Please enter a valid amount."
            showValidationError = true
            return
        }

        // Check transaction limit for free users
        if !isEditing && !premiumManager.canAddTransaction(count: allTransactions.count) {
            showPaywall = true
            return
        }

        if let existing = transaction {
            // Edit mode
            existing.title = title
            existing.amount = amount
            existing.type = selectedType
            existing.categoryID = selectedCategoryID
            existing.accountID = selectedAccountID
            existing.date = date
            existing.notes = notes
            existing.tags = tags
            existing.recurrence = isRecurring ? recurrence : .none
            existing.isRecurring = isRecurring
            existing.updatedAt = Date()
        } else {
            // Add mode
            let newTransaction = Transaction(
                title: title,
                amount: amount,
                type: selectedType,
                categoryID: selectedCategoryID,
                accountID: selectedAccountID,
                date: date,
                notes: notes,
                tags: tags,
                recurrence: isRecurring ? recurrence : .none,
                isRecurring: isRecurring
            )
            modelContext.insert(newTransaction)
            AnalyticsService.shared.track(.transactionAdded(type: selectedType.rawValue, amount: amount))
        }

        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .environment(PremiumManager())
        .modelContainer(for: [
            Transaction.self, Account.self, Category.self, Budget.self,
            BillReminder.self, NetWorthItem.self, NetWorthSnapshot.self
        ], inMemory: true)
}
