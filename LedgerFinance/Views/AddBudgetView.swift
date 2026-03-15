//
//  AddBudgetView.swift
//  LedgerFinance
//
//  Create or edit a budget
//

import SwiftUI
import SwiftData

struct AddBudgetView: View {
    var budget: Budget? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var categories: [Category]

    @State private var name: String = ""
    @State private var limitText: String = ""
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var selectedCategoryID: UUID? = nil
    @State private var alertThreshold: Double = 0.8
    @State private var colorHex: String = "4A90D9"
    @State private var rolloverUnused: Bool = false

    private var isEditing: Bool { budget != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Details") {
                    TextField("Budget Name", text: $name)

                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Limit", text: $limitText)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.rawValue) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                }

                Section("Category (Optional)") {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("All Expenses").tag(Optional<UUID>(nil))
                        ForEach(expenseCategories) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(Color(hex: cat.colorHex))
                                Text(cat.name)
                            }
                            .tag(Optional(cat.id))
                        }
                    }
                }

                Section("Alert Threshold") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert when spending reaches \(Int(alertThreshold * 100))%")
                            .font(.subheadline)
                        Slider(value: $alertThreshold, in: 0.5...1.0, step: 0.05)
                            .tint(.orange)
                    }
                }

                Section("Options") {
                    Toggle("Roll over unused budget", isOn: $rolloverUnused)
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Create") { saveBudget() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || limitText.isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let b = budget else { return }
        name = b.name
        limitText = String(b.limit)
        selectedPeriod = b.period
        selectedCategoryID = b.categoryID
        alertThreshold = b.alertThreshold
        rolloverUnused = b.rolloverUnused
    }

    private func saveBudget() {
        guard !name.isEmpty, let limit = Double(limitText), limit > 0 else { return }

        if let existing = budget {
            existing.name = name
            existing.limit = limit
            existing.period = selectedPeriod
            existing.categoryID = selectedCategoryID
            existing.alertThreshold = alertThreshold
            existing.rolloverUnused = rolloverUnused
            existing.updatedAt = Date()
        } else {
            let newBudget = Budget(
                name: name,
                categoryID: selectedCategoryID,
                limit: limit,
                period: selectedPeriod,
                rolloverUnused: rolloverUnused,
                alertThreshold: alertThreshold
            )
            modelContext.insert(newBudget)
            AnalyticsService.shared.track(.budgetCreated)
        }
        dismiss()
    }
}
