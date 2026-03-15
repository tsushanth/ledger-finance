//
//  NetWorthView.swift
//  LedgerFinance
//
//  Net worth tracking - assets & liabilities
//

import SwiftUI
import SwiftData
import Charts

struct NetWorthView: View {
    @Query private var items: [NetWorthItem]
    @Query(sort: \NetWorthSnapshot.date) private var snapshots: [NetWorthSnapshot]
    @Query private var accounts: [Account]

    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var showAddItem: Bool = false
    @State private var selectedItemType: NetWorthItemType = .asset
    @State private var showPaywall: Bool = false

    private var assets: [NetWorthItem] { items.filter { $0.itemType == .asset }.sorted { $0.value > $1.value } }
    private var liabilities: [NetWorthItem] { items.filter { $0.itemType == .liability }.sorted { $0.value > $1.value } }
    private var totalAssets: Double { assets.reduce(0) { $0 + $1.value } }
    private var totalLiabilities: Double { liabilities.reduce(0) { $0 + $1.value } }
    private var netWorth: Double { totalAssets - totalLiabilities }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Paywall gate
                    if !premiumManager.canTrackNetWorth {
                        netWorthPaywall
                    } else {
                        // Net Worth Header
                        netWorthHeader

                        // Trend Chart
                        if !snapshots.isEmpty {
                            trendChart
                        }

                        // Assets Section
                        itemsSection(title: "Assets", items: assets, total: totalAssets, type: .asset, color: .green)

                        // Liabilities Section
                        itemsSection(title: "Liabilities", items: liabilities, total: totalLiabilities, type: .liability, color: .red)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Net Worth")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if premiumManager.canTrackNetWorth {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddNetWorthItemView(defaultType: selectedItemType)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "net_worth")
            }
        }
    }

    // MARK: - Paywall Banner
    private var netWorthPaywall: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Track Your Net Worth")
                .font(.title2)
                .fontWeight(.bold)

            Text("Monitor all your assets and liabilities in one place. See your wealth grow over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Upgrade to Premium") {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Net Worth Header
    private var netWorthHeader: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(formatCurrency(netWorth))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Divider()
                .background(.white.opacity(0.3))

            HStack {
                VStack(spacing: 4) {
                    Text("Assets")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formatCurrency(totalAssets))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("Liabilities")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formatCurrency(totalLiabilities))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Trend Chart
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth Over Time")
                .font(.headline)

            Chart(snapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 160)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Items Section
    private func itemsSection(
        title: String,
        items: [NetWorthItem],
        total: Double,
        type: NetWorthItemType,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(formatCurrency(total))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Button {
                    selectedItemType = type
                    showAddItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(color)
                }
            }

            if items.isEmpty {
                Text("No \(title.lowercased()) added yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    NetWorthItemRow(item: item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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

// MARK: - Net Worth Item Row
struct NetWorthItemRow: View {
    let item: NetWorthItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: item.colorHex).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: item.icon)
                        .font(.callout)
                        .foregroundStyle(Color(hex: item.colorHex))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !item.institution.isEmpty {
                    Text(item.institution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.formattedValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.itemType == .asset ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Net Worth Item
struct AddNetWorthItemView: View {
    var defaultType: NetWorthItemType = .asset
    var existingItem: NetWorthItem? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var valueText: String = ""
    @State private var itemType: NetWorthItemType = .asset
    @State private var assetCategory: AssetCategory = .bankAccount
    @State private var liabilityCategory: LiabilityCategory = .creditCard
    @State private var institution: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $itemType) {
                        ForEach(NetWorthItemType.allCases, id: \.rawValue) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Value", text: $valueText)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Institution (optional)", text: $institution)
                }

                Section("Category") {
                    if itemType == .asset {
                        Picker("Asset Category", selection: $assetCategory) {
                            ForEach(AssetCategory.allCases, id: \.rawValue) { cat in
                                Label(cat.displayName, systemImage: cat.systemImage).tag(cat)
                            }
                        }
                    } else {
                        Picker("Liability Category", selection: $liabilityCategory) {
                            ForEach(LiabilityCategory.allCases, id: \.rawValue) { cat in
                                Label(cat.displayName, systemImage: cat.systemImage).tag(cat)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(existingItem == nil ? "Add \(itemType.displayName)" : "Edit \(itemType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveItem() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || valueText.isEmpty)
                }
            }
            .onAppear {
                itemType = defaultType
                if let item = existingItem {
                    name = item.name
                    valueText = String(item.value)
                    itemType = item.itemType
                    institution = item.institution
                    notes = item.notes
                }
            }
        }
    }

    private func saveItem() {
        guard !name.isEmpty, let value = Double(valueText), value > 0 else { return }

        let icon = itemType == .asset ? assetCategory.systemImage : liabilityCategory.systemImage
        let colorHex = itemType == .asset ? "27AE60" : "E74C3C"

        if let existing = existingItem {
            existing.name = name
            existing.value = value
            existing.institution = institution
            existing.notes = notes
            existing.lastUpdated = Date()
        } else {
            let item = NetWorthItem(
                name: name,
                value: value,
                itemType: itemType,
                assetCategory: itemType == .asset ? assetCategory : nil,
                liabilityCategory: itemType == .liability ? liabilityCategory : nil,
                institution: institution,
                notes: notes,
                colorHex: colorHex,
                icon: icon
            )
            modelContext.insert(item)
        }
        dismiss()
    }
}
