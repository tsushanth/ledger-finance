//
//  NetWorthEntry.swift
//  LedgerFinance
//
//  SwiftData model for net worth tracking (assets & liabilities)
//

import Foundation
import SwiftData

// MARK: - Asset/Liability Type
enum NetWorthItemType: String, Codable, CaseIterable {
    case asset = "asset"
    case liability = "liability"

    var displayName: String {
        switch self {
        case .asset: return "Asset"
        case .liability: return "Liability"
        }
    }

    var systemImage: String {
        switch self {
        case .asset: return "plus.circle.fill"
        case .liability: return "minus.circle.fill"
        }
    }
}

// MARK: - Asset Category
enum AssetCategory: String, Codable, CaseIterable {
    case cash = "cash"
    case bankAccount = "bankAccount"
    case investment = "investment"
    case realEstate = "realEstate"
    case vehicle = "vehicle"
    case retirement = "retirement"
    case crypto = "crypto"
    case other = "other"

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .bankAccount: return "Bank Account"
        case .investment: return "Investment"
        case .realEstate: return "Real Estate"
        case .vehicle: return "Vehicle"
        case .retirement: return "Retirement"
        case .crypto: return "Cryptocurrency"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "dollarsign.circle.fill"
        case .bankAccount: return "building.columns.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .realEstate: return "house.fill"
        case .vehicle: return "car.fill"
        case .retirement: return "umbrella.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Liability Category
enum LiabilityCategory: String, Codable, CaseIterable {
    case mortgage = "mortgage"
    case autoLoan = "autoLoan"
    case studentLoan = "studentLoan"
    case creditCard = "creditCard"
    case personalLoan = "personalLoan"
    case medicalDebt = "medicalDebt"
    case other = "other"

    var displayName: String {
        switch self {
        case .mortgage: return "Mortgage"
        case .autoLoan: return "Auto Loan"
        case .studentLoan: return "Student Loan"
        case .creditCard: return "Credit Card"
        case .personalLoan: return "Personal Loan"
        case .medicalDebt: return "Medical Debt"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .mortgage: return "house.fill"
        case .autoLoan: return "car.fill"
        case .studentLoan: return "graduationcap.fill"
        case .creditCard: return "creditcard.fill"
        case .personalLoan: return "person.fill"
        case .medicalDebt: return "heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Net Worth Item Model
@Model
final class NetWorthItem {
    var id: UUID
    var name: String
    var value: Double
    var itemType: NetWorthItemType
    var assetCategoryRaw: String?
    var liabilityCategoryRaw: String?
    var institution: String
    var notes: String
    var colorHex: String
    var icon: String
    var isLinkedAccount: Bool
    var linkedAccountID: UUID?
    var lastUpdated: Date
    var createdAt: Date

    var assetCategory: AssetCategory? {
        get {
            guard let raw = assetCategoryRaw else { return nil }
            return AssetCategory(rawValue: raw)
        }
        set { assetCategoryRaw = newValue?.rawValue }
    }

    var liabilityCategory: LiabilityCategory? {
        get {
            guard let raw = liabilityCategoryRaw else { return nil }
            return LiabilityCategory(rawValue: raw)
        }
        set { liabilityCategoryRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        itemType: NetWorthItemType,
        assetCategory: AssetCategory? = nil,
        liabilityCategory: LiabilityCategory? = nil,
        institution: String = "",
        notes: String = "",
        colorHex: String = "4A90D9",
        icon: String = "dollarsign.circle.fill",
        isLinkedAccount: Bool = false,
        linkedAccountID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.value = abs(value)
        self.itemType = itemType
        self.assetCategoryRaw = assetCategory?.rawValue
        self.liabilityCategoryRaw = liabilityCategory?.rawValue
        self.institution = institution
        self.notes = notes
        self.colorHex = colorHex
        self.icon = icon
        self.isLinkedAccount = isLinkedAccount
        self.linkedAccountID = linkedAccountID
        self.lastUpdated = Date()
        self.createdAt = Date()
    }

    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Net Worth Snapshot (historical)
@Model
final class NetWorthSnapshot {
    var id: UUID
    var date: Date
    var totalAssets: Double
    var totalLiabilities: Double
    var netWorth: Double
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalAssets: Double,
        totalLiabilities: Double,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
        self.netWorth = totalAssets - totalLiabilities
        self.notes = notes
    }
}
