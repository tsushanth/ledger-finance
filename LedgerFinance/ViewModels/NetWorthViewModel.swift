//
//  NetWorthViewModel.swift
//  LedgerFinance
//
//  ViewModel for net worth tracking
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class NetWorthViewModel {
    // MARK: - State
    var items: [NetWorthItem] = []
    var snapshots: [NetWorthSnapshot] = []
    var accounts: [Account] = []

    var isLoading: Bool = false
    var showAddItem: Bool = false
    var selectedItem: NetWorthItem?
    var errorMessage: String?

    // MARK: - Computed
    var assets: [NetWorthItem] {
        items.filter { $0.itemType == .asset }.sorted { $0.value > $1.value }
    }

    var liabilities: [NetWorthItem] {
        items.filter { $0.itemType == .liability }.sorted { $0.value > $1.value }
    }

    var totalAssets: Double {
        assets.reduce(0) { $0 + $1.value }
    }

    var totalLiabilities: Double {
        liabilities.reduce(0) { $0 + $1.value }
    }

    var netWorth: Double {
        totalAssets - totalLiabilities
    }

    var debtToAssetRatio: Double {
        guard totalAssets > 0 else { return 0 }
        return totalLiabilities / totalAssets
    }

    var assetAllocationData: [ChartDataPoint] {
        let grouped = Dictionary(grouping: assets) { $0.assetCategory ?? .other }
        return grouped.map { cat, items in
            let total = items.reduce(0) { $0 + $1.value }
            return ChartDataPoint(label: cat.displayName, value: total, colorHex: colorForAssetCategory(cat))
        }
        .sorted { $0.value > $1.value }
    }

    var netWorthTrendData: [ChartDataPoint] {
        let df = DateFormatter()
        df.dateFormat = "MMM yy"
        return snapshots
            .sorted { $0.date < $1.date }
            .map { snapshot in
                ChartDataPoint(label: df.string(from: snapshot.date), value: snapshot.netWorth, date: snapshot.date)
            }
    }

    // MARK: - Net Worth Change
    var netWorthChange: Double {
        guard let lastSnapshot = snapshots.sorted(by: { $0.date > $1.date }).first else { return 0 }
        return netWorth - lastSnapshot.netWorth
    }

    var netWorthChangePercent: Double {
        guard let lastSnapshot = snapshots.sorted(by: { $0.date > $1.date }).first,
              lastSnapshot.netWorth != 0 else { return 0 }
        return ((netWorth - lastSnapshot.netWorth) / abs(lastSnapshot.netWorth)) * 100
    }

    // MARK: - Take Snapshot
    func takeSnapshot(context: ModelContext) {
        let snapshot = NetWorthSnapshot(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities
        )
        context.insert(snapshot)
        snapshots.append(snapshot)
    }

    // MARK: - Sync from Accounts
    func syncFromAccounts() {
        // Create or update net worth items from linked accounts
        for account in accounts {
            if let existing = items.first(where: { $0.linkedAccountID == account.id }) {
                existing.value = abs(account.balance)
                existing.lastUpdated = Date()
            }
        }
    }

    // MARK: - Delete
    func deleteItem(_ item: NetWorthItem, from context: ModelContext) {
        context.delete(item)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }

    // MARK: - Helpers
    private func colorForAssetCategory(_ category: AssetCategory) -> String {
        switch category {
        case .cash: return "F39C12"
        case .bankAccount: return "4A90D9"
        case .investment: return "27AE60"
        case .realEstate: return "E74C3C"
        case .vehicle: return "9B59B6"
        case .retirement: return "16A085"
        case .crypto: return "F7931A"
        case .other: return "95A5A6"
        }
    }

    var formattedNetWorth: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: netWorth)) ?? "$\(netWorth)"
    }
}
