//
//  NotificationManager.swift
//  LedgerFinance
//
//  Local notification scheduling for bill reminders and budget alerts
//

import Foundation
import UserNotifications

// MARK: - Notification Category
enum NotificationCategory: String {
    case billReminder = "BILL_REMINDER"
    case budgetAlert = "BUDGET_ALERT"
    case weeklySummary = "WEEKLY_SUMMARY"
    case monthlySummary = "MONTHLY_SUMMARY"
}

// MARK: - Notification Action
enum NotificationAction: String {
    case markPaid = "MARK_PAID"
    case viewBill = "VIEW_BILL"
    case viewBudget = "VIEW_BUDGET"
    case dismiss = "DISMISS"
}

// MARK: - Notification Manager
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                setupNotificationCategories()
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Categories Setup
    private func setupNotificationCategories() {
        let markPaidAction = UNNotificationAction(
            identifier: NotificationAction.markPaid.rawValue,
            title: "Mark as Paid",
            options: .foreground
        )
        let viewBillAction = UNNotificationAction(
            identifier: NotificationAction.viewBill.rawValue,
            title: "View Bill",
            options: .foreground
        )
        let viewBudgetAction = UNNotificationAction(
            identifier: NotificationAction.viewBudget.rawValue,
            title: "View Budget",
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: .destructive
        )

        let billCategory = UNNotificationCategory(
            identifier: NotificationCategory.billReminder.rawValue,
            actions: [markPaidAction, viewBillAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let budgetCategory = UNNotificationCategory(
            identifier: NotificationCategory.budgetAlert.rawValue,
            actions: [viewBudgetAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([billCategory, budgetCategory])
    }

    // MARK: - Bill Reminders
    func scheduleBillReminder(_ bill: BillReminder) async {
        // Cancel existing notifications for this bill
        cancelNotification(identifier: "bill-\(bill.id.uuidString)")

        guard bill.isActive && !bill.isPaid else { return }

        // Schedule reminder X days before due date
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -bill.reminderDaysBefore,
            to: bill.dueDate
        ) ?? bill.dueDate

        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bill Due Soon"
        content.body = "\(bill.title) — \(bill.formattedAmount) due in \(bill.reminderDaysBefore) days"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.billReminder.rawValue
        content.userInfo = ["billID": bill.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "bill-\(bill.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule bill notification: \(error)")
        }

        // Also schedule a notification on the due date if different
        if bill.reminderDaysBefore > 0 {
            let dueDayContent = UNMutableNotificationContent()
            dueDayContent.title = "Bill Due Today"
            dueDayContent.body = "\(bill.title) — \(bill.formattedAmount) is due today!"
            dueDayContent.sound = .default
            dueDayContent.categoryIdentifier = NotificationCategory.billReminder.rawValue
            dueDayContent.userInfo = ["billID": bill.id.uuidString]

            guard bill.dueDate > Date() else { return }
            var dueComponents = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: bill.dueDate
            )
            dueComponents.hour = 9
            dueComponents.minute = 0

            let dueTrigger = UNCalendarNotificationTrigger(dateMatching: dueComponents, repeats: false)
            let dueRequest = UNNotificationRequest(
                identifier: "bill-due-\(bill.id.uuidString)",
                content: dueDayContent,
                trigger: dueTrigger
            )

            do {
                try await center.add(dueRequest)
            } catch {
                print("Failed to schedule due-day notification: \(error)")
            }
        }
    }

    // MARK: - Budget Alerts
    func sendBudgetAlert(budget: Budget, spent: Double) async {
        let progress = budget.progressPercentage(spent: spent)
        guard progress >= budget.alertThreshold else { return }

        let percentage = Int(progress * 100)
        let isOver = progress >= 1.0

        let content = UNMutableNotificationContent()
        content.title = isOver ? "Budget Exceeded!" : "Budget Alert"
        content.body = isOver
            ? "\(budget.name) budget exceeded by \(budget.formattedLimit)"
            : "\(budget.name) is at \(percentage)% of budget limit"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.budgetAlert.rawValue
        content.userInfo = ["budgetID": budget.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "budget-alert-\(budget.id.uuidString)-\(percentage)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to send budget alert: \(error)")
        }
    }

    // MARK: - Weekly Summary
    func scheduleWeeklySummary(hour: Int = 9, weekday: Int = 2) async {
        cancelNotification(identifier: "weekly-summary")

        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Summary"
        content.body = "See how you did this week — tap to view your spending report"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.weeklySummary.rawValue

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly-summary",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule weekly summary: \(error)")
        }
    }

    // MARK: - Cancel
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAllBillNotifications(for billID: UUID) {
        let ids = [
            "bill-\(billID.uuidString)",
            "bill-due-\(billID.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
