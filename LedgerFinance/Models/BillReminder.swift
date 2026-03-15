//
//  BillReminder.swift
//  LedgerFinance
//
//  SwiftData model for bill reminders
//

import Foundation
import SwiftData

// MARK: - Bill Status
enum BillStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case due = "due"
    case overdue = "overdue"
    case paid = "paid"

    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .due: return "Due Today"
        case .overdue: return "Overdue"
        case .paid: return "Paid"
        }
    }

    var systemImage: String {
        switch self {
        case .upcoming: return "clock.fill"
        case .due: return "exclamationmark.circle.fill"
        case .overdue: return "xmark.circle.fill"
        case .paid: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Bill Reminder Model
@Model
final class BillReminder {
    var id: UUID
    var title: String
    var amount: Double
    var dueDate: Date
    var categoryID: UUID?
    var accountID: UUID?
    var recurrence: RecurrenceFrequency
    var isPaid: Bool
    var paidDate: Date?
    var reminderDaysBefore: Int
    var notes: String
    var colorHex: String
    var icon: String
    var isActive: Bool
    var autoPay: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        dueDate: Date,
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        recurrence: RecurrenceFrequency = .monthly,
        isPaid: Bool = false,
        paidDate: Date? = nil,
        reminderDaysBefore: Int = 3,
        notes: String = "",
        colorHex: String = "E74C3C",
        icon: String = "calendar.badge.exclamationmark",
        isActive: Bool = true,
        autoPay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = abs(amount)
        self.dueDate = dueDate
        self.categoryID = categoryID
        self.accountID = accountID
        self.recurrence = recurrence
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.reminderDaysBefore = reminderDaysBefore
        self.notes = notes
        self.colorHex = colorHex
        self.icon = icon
        self.isActive = isActive
        self.autoPay = autoPay
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var status: BillStatus {
        if isPaid { return .paid }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)

        if due < today {
            return .overdue
        } else if due == today {
            return .due
        } else {
            return .upcoming
        }
    }

    var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    func nextDueDate() -> Date? {
        guard recurrence != .none else { return nil }
        let calendar = Calendar.current

        switch recurrence {
        case .none: return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: dueDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: dueDate)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: dueDate)
        }
    }
}

// MARK: - Sample Bill Reminders
extension BillReminder {
    static var samples: [BillReminder] {
        let calendar = Calendar.current
        let now = Date()

        return [
            BillReminder(title: "Rent", amount: 1500, dueDate: calendar.date(byAdding: .day, value: 5, to: now)!,
                        recurrence: .monthly, colorHex: "E74C3C", icon: "house.fill"),
            BillReminder(title: "Electric Bill", amount: 85, dueDate: calendar.date(byAdding: .day, value: 10, to: now)!,
                        recurrence: .monthly, colorHex: "F39C12", icon: "bolt.fill"),
            BillReminder(title: "Internet", amount: 60, dueDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                        recurrence: .monthly, colorHex: "3498DB", icon: "wifi"),
            BillReminder(title: "Car Insurance", amount: 120, dueDate: calendar.date(byAdding: .day, value: 15, to: now)!,
                        recurrence: .monthly, colorHex: "27AE60", icon: "car.fill"),
        ]
    }
}
