//
//  Category.swift
//  LedgerFinance
//
//  SwiftData model for transaction categories
//

import Foundation
import SwiftData

// MARK: - Category Model
@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var type: TransactionType
    var isSystem: Bool
    var isArchived: Bool
    var parentCategoryID: UUID?
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        isSystem: Bool = false,
        isArchived: Bool = false,
        parentCategoryID: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
        self.isSystem = isSystem
        self.isArchived = isArchived
        self.parentCategoryID = parentCategoryID
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

// MARK: - Default Categories
extension Category {
    static var defaultExpenseCategories: [Category] {
        [
            Category(name: "Food & Dining", icon: "fork.knife", colorHex: "FF6B6B", type: .expense, isSystem: true, sortOrder: 0),
            Category(name: "Transportation", icon: "car.fill", colorHex: "4ECDC4", type: .expense, isSystem: true, sortOrder: 1),
            Category(name: "Shopping", icon: "bag.fill", colorHex: "45B7D1", type: .expense, isSystem: true, sortOrder: 2),
            Category(name: "Entertainment", icon: "tv.fill", colorHex: "96CEB4", type: .expense, isSystem: true, sortOrder: 3),
            Category(name: "Housing", icon: "house.fill", colorHex: "FFEAA7", type: .expense, isSystem: true, sortOrder: 4),
            Category(name: "Utilities", icon: "bolt.fill", colorHex: "DDA0DD", type: .expense, isSystem: true, sortOrder: 5),
            Category(name: "Healthcare", icon: "heart.fill", colorHex: "FF9FF3", type: .expense, isSystem: true, sortOrder: 6),
            Category(name: "Insurance", icon: "shield.fill", colorHex: "54A0FF", type: .expense, isSystem: true, sortOrder: 7),
            Category(name: "Education", icon: "book.fill", colorHex: "5F27CD", type: .expense, isSystem: true, sortOrder: 8),
            Category(name: "Personal Care", icon: "person.fill", colorHex: "FF9F43", type: .expense, isSystem: true, sortOrder: 9),
            Category(name: "Travel", icon: "airplane", colorHex: "00B894", type: .expense, isSystem: true, sortOrder: 10),
            Category(name: "Subscriptions", icon: "repeat.circle.fill", colorHex: "6C5CE7", type: .expense, isSystem: true, sortOrder: 11),
            Category(name: "Gifts & Donations", icon: "gift.fill", colorHex: "E17055", type: .expense, isSystem: true, sortOrder: 12),
            Category(name: "Other", icon: "ellipsis.circle.fill", colorHex: "B2BEC3", type: .expense, isSystem: true, sortOrder: 13),
        ]
    }

    static var defaultIncomeCategories: [Category] {
        [
            Category(name: "Salary", icon: "briefcase.fill", colorHex: "00B894", type: .income, isSystem: true, sortOrder: 0),
            Category(name: "Freelance", icon: "laptopcomputer", colorHex: "0984E3", type: .income, isSystem: true, sortOrder: 1),
            Category(name: "Business", icon: "building.2.fill", colorHex: "6C5CE7", type: .income, isSystem: true, sortOrder: 2),
            Category(name: "Investments", icon: "chart.line.uptrend.xyaxis", colorHex: "FDCB6E", type: .income, isSystem: true, sortOrder: 3),
            Category(name: "Rental Income", icon: "house.fill", colorHex: "E17055", type: .income, isSystem: true, sortOrder: 4),
            Category(name: "Gifts Received", icon: "gift.fill", colorHex: "FF7675", type: .income, isSystem: true, sortOrder: 5),
            Category(name: "Refunds", icon: "arrow.uturn.left.circle.fill", colorHex: "74B9FF", type: .income, isSystem: true, sortOrder: 6),
            Category(name: "Other Income", icon: "ellipsis.circle.fill", colorHex: "B2BEC3", type: .income, isSystem: true, sortOrder: 7),
        ]
    }

    static var allDefaultCategories: [Category] {
        defaultExpenseCategories + defaultIncomeCategories
    }
}
