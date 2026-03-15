//
//  TransactionRowView.swift
//  LedgerFinance
//
//  Reusable row view for a single transaction
//

import SwiftUI
import SwiftData

struct TransactionRowView: View {
    let transaction: Transaction

    @Query private var categories: [Category]
    @Query private var accounts: [Account]

    private var category: Category? {
        guard let catID = transaction.categoryID else { return nil }
        return categories.first { $0.id == catID }
    }

    private var account: Account? {
        guard let accID = transaction.accountID else { return nil }
        return accounts.first { $0.id == accID }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            categoryIcon

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let cat = category {
                        Text(cat.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let acc = account {
                        Text("· \(acc.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Amount & Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: some View {
        Circle()
            .fill(iconBackgroundColor.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: iconName)
                    .font(.callout)
                    .foregroundStyle(iconBackgroundColor)
            }
    }

    private var iconName: String {
        if let cat = category { return cat.icon }
        return transaction.type.systemImage
    }

    private var iconBackgroundColor: Color {
        if let cat = category { return Color(hex: cat.colorHex) }
        switch transaction.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }

    private var amountString: String {
        let prefix = transaction.type == .income ? "+" : transaction.type == .expense ? "-" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return "\(prefix)\(formatter.string(from: NSNumber(value: transaction.amount)) ?? "$\(transaction.amount)")"
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: return .green
        case .expense: return .primary
        case .transfer: return .blue
        }
    }

    private var timeString: String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: transaction.date)
    }
}

// MARK: - Transaction Detail
struct TransactionDetailView: View {
    let transaction: Transaction
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet: Bool = false
    @State private var showDeleteAlert: Bool = false

    private var category: Category? {
        guard let catID = transaction.categoryID else { return nil }
        return categories.first { $0.id == catID }
    }

    private var account: Account? {
        guard let accID = transaction.accountID else { return nil }
        return accounts.first { $0.id == accID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Amount Header
                amountHeader

                // Details Card
                detailsCard

                // Notes
                if !transaction.notes.isEmpty {
                    notesCard
                }

                // Tags
                if !transaction.tags.isEmpty {
                    tagsCard
                }

                // Actions
                actionButtons
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddTransactionView(transaction: transaction)
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(transaction)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 8) {
            Text(transaction.type.displayName)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(transaction.formattedAmount)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(transaction.type == .income ? .green : .primary)

            Text(fullDateString(transaction.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailRow(label: "Title", value: transaction.title)
            Divider().padding(.leading, 16)
            if let cat = category {
                detailRow(label: "Category", value: cat.name)
                Divider().padding(.leading, 16)
            }
            if let acc = account {
                detailRow(label: "Account", value: acc.name)
                Divider().padding(.leading, 16)
            }
            if transaction.isRecurring {
                detailRow(label: "Recurrence", value: transaction.recurrence.displayName)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(transaction.notes)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(transaction.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Label("Delete Transaction", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func fullDateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height = y + rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
