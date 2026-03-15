//
//  BillRemindersView.swift
//  LedgerFinance
//
//  Bill reminders management
//

import SwiftUI
import SwiftData

struct BillRemindersView: View {
    @Query(sort: \BillReminder.dueDate) private var bills: [BillReminder]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddBill: Bool = false
    @State private var billToDelete: BillReminder?
    @State private var showDeleteAlert: Bool = false
    @State private var selectedFilter: BillFilter = .all

    enum BillFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case paid = "Paid"
    }

    private var filteredBills: [BillReminder] {
        switch selectedFilter {
        case .all: return bills
        case .upcoming: return bills.filter { !$0.isPaid && $0.daysUntilDue > 0 }
        case .overdue: return bills.filter { $0.status == .overdue }
        case .paid: return bills.filter { $0.isPaid }
        }
    }

    private var totalUpcoming: Double {
        bills.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Tabs
                filterTabs

                // Summary
                if !bills.isEmpty {
                    billSummary
                }

                // List
                billList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bills & Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddBill = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddBill) {
                AddBillReminderView()
            }
            .alert("Delete Bill?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let bill = billToDelete {
                        NotificationManager.shared.cancelAllBillNotifications(for: bill.id)
                        modelContext.delete(bill)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BillFilter.allCases, id: \.rawValue) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedFilter == filter ? Color.blue : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var billSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Upcoming Bills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(totalUpcoming))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Overdue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(bills.filter { $0.status == .overdue }.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var billList: some View {
        Group {
            if filteredBills.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredBills) { bill in
                        BillRowView(bill: bill) {
                            togglePaid(bill)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                billToDelete = bill
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                togglePaid(bill)
                            } label: {
                                Label(bill.isPaid ? "Unpaid" : "Paid", systemImage: bill.isPaid ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(bill.isPaid ? .orange : .green)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No bills yet")
                .font(.headline)
            Text("Track your recurring bills and never miss a payment")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Bill Reminder") {
                showAddBill = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func togglePaid(_ bill: BillReminder) {
        bill.isPaid.toggle()
        bill.paidDate = bill.isPaid ? Date() : nil
        bill.updatedAt = Date()

        if bill.isPaid {
            NotificationManager.shared.cancelAllBillNotifications(for: bill.id)
        } else {
            Task {
                await NotificationManager.shared.scheduleBillReminder(bill)
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

// MARK: - Bill Row
struct BillRowView: View {
    let bill: BillReminder
    let onTogglePaid: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Button(action: onTogglePaid) {
                Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(bill.isPaid ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Icon
            Circle()
                .fill(Color(hex: bill.colorHex).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: bill.icon)
                        .font(.callout)
                        .foregroundStyle(Color(hex: bill.colorHex))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(bill.isPaid)

                HStack(spacing: 4) {
                    Image(systemName: bill.status.systemImage)
                        .font(.caption2)
                    Text(dueText)
                        .font(.caption)
                }
                .foregroundStyle(statusColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(bill.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(bill.isPaid ? .secondary : .primary)
                Text(bill.recurrence.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var dueText: String {
        if bill.isPaid {
            if let paidDate = bill.paidDate {
                let df = DateFormatter()
                df.dateStyle = .short
                return "Paid \(df.string(from: paidDate))"
            }
            return "Paid"
        }
        switch bill.status {
        case .overdue:
            return "Overdue by \(abs(bill.daysUntilDue)) days"
        case .due:
            return "Due today"
        case .upcoming:
            return "Due in \(bill.daysUntilDue) days"
        case .paid:
            return "Paid"
        }
    }

    private var statusColor: Color {
        if bill.isPaid { return .secondary }
        switch bill.status {
        case .overdue: return .red
        case .due: return .orange
        case .upcoming: return .secondary
        case .paid: return .green
        }
    }
}

// MARK: - Add Bill Reminder
struct AddBillReminderView: View {
    var bill: BillReminder? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var dueDate: Date = Date()
    @State private var recurrence: RecurrenceFrequency = .monthly
    @State private var reminderDaysBefore: Int = 3
    @State private var notes: String = ""
    @State private var autoPay: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Bill Name", text: $title)
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }

                Section("Recurrence") {
                    Picker("Frequency", selection: $recurrence) {
                        ForEach(RecurrenceFrequency.allCases, id: \.rawValue) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section("Reminder") {
                    Stepper("Remind \(reminderDaysBefore) days before", value: $reminderDaysBefore, in: 0...14)
                    Toggle("Auto Pay", isOn: $autoPay)
                }

                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle(bill == nil ? "Add Bill Reminder" : "Edit Bill Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(bill == nil ? "Add" : "Save") { saveBill() }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty || amountText.isEmpty)
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard let b = bill else { return }
        title = b.title
        amountText = String(b.amount)
        dueDate = b.dueDate
        recurrence = b.recurrence
        reminderDaysBefore = b.reminderDaysBefore
        notes = b.notes
        autoPay = b.autoPay
    }

    private func saveBill() {
        guard let amount = Double(amountText), amount > 0 else { return }

        if let existing = bill {
            existing.title = title
            existing.amount = amount
            existing.dueDate = dueDate
            existing.recurrence = recurrence
            existing.reminderDaysBefore = reminderDaysBefore
            existing.notes = notes
            existing.autoPay = autoPay
            existing.updatedAt = Date()
        } else {
            let newBill = BillReminder(
                title: title,
                amount: amount,
                dueDate: dueDate,
                recurrence: recurrence,
                reminderDaysBefore: reminderDaysBefore,
                notes: notes,
                autoPay: autoPay
            )
            modelContext.insert(newBill)
            AnalyticsService.shared.track(.billReminderCreated)

            Task {
                await NotificationManager.shared.scheduleBillReminder(newBill)
            }
        }
        dismiss()
    }
}
