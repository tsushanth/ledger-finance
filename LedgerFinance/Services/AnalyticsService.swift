//
//  AnalyticsService.swift
//  LedgerFinance
//
//  Firebase Analytics + Facebook SDK + ATT + AdServices wrappers
//

import Foundation
import AppTrackingTransparency
import AdServices

// MARK: - Analytics Event
enum AnalyticsEvent {
    case appOpen
    case onboardingStart
    case onboardingComplete
    case signUp(method: String)
    case transactionAdded(type: String, amount: Double)
    case transactionDeleted
    case budgetCreated
    case budgetAlert(name: String)
    case billReminderCreated
    case reportViewed(type: String)
    case exportCompleted(format: String)
    case netWorthViewed
    case paywallViewed(source: String)
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String)
    case purchaseFailed(reason: String)
    case purchaseCancelled
    case restorePurchases
    case accountAdded(type: String)
    case settingsChanged(key: String)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .onboardingStart: return "onboarding_start"
        case .onboardingComplete: return "onboarding_complete"
        case .signUp: return "sign_up"
        case .transactionAdded: return "transaction_added"
        case .transactionDeleted: return "transaction_deleted"
        case .budgetCreated: return "budget_created"
        case .budgetAlert: return "budget_alert"
        case .billReminderCreated: return "bill_reminder_created"
        case .reportViewed: return "report_viewed"
        case .exportCompleted: return "export_completed"
        case .netWorthViewed: return "net_worth_viewed"
        case .paywallViewed: return "paywall_viewed"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .purchaseCancelled: return "purchase_cancelled"
        case .restorePurchases: return "restore_purchases"
        case .accountAdded: return "account_added"
        case .settingsChanged: return "settings_changed"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .signUp(let method):
            return ["method": method]
        case .transactionAdded(let type, let amount):
            return ["type": type, "amount": amount]
        case .budgetAlert(let name):
            return ["budget_name": name]
        case .reportViewed(let type):
            return ["report_type": type]
        case .exportCompleted(let format):
            return ["format": format]
        case .paywallViewed(let source):
            return ["source": source]
        case .purchaseStarted(let productID),
             .purchaseCompleted(let productID):
            return ["product_id": productID]
        case .purchaseFailed(let reason):
            return ["reason": reason]
        case .accountAdded(let type):
            return ["account_type": type]
        case .settingsChanged(let key):
            return ["key": key]
        default:
            return [:]
        }
    }
}

// MARK: - Analytics Service
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()
    private var isInitialized = false
    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        // Firebase initialization happens via GoogleService-Info.plist
        // FirebaseApp.configure() — would be called here with Firebase SDK
        // Analytics.setAnalyticsCollectionEnabled(true)

        // Facebook SDK initialization
        // ApplicationDelegate.shared.application(...)

        #if DEBUG
        print("[AnalyticsService] Initialized (debug mode)")
        #endif
    }

    func track(_ event: AnalyticsEvent) {
        guard isInitialized else { return }

        #if DEBUG
        print("[Analytics] \(event.name): \(event.parameters)")
        #endif

        // Firebase Analytics — would be called with real SDK:
        // Analytics.logEvent(event.name, parameters: event.parameters)

        // Facebook App Events — would be called with real SDK:
        // AppEvents.shared.logEvent(AppEvents.Name(event.name), parameters: event.parameters)
    }

    func setUserProperty(key: String, value: String?) {
        #if DEBUG
        print("[Analytics] setUserProperty: \(key) = \(value ?? "nil")")
        #endif
        // Analytics.setUserProperty(value, forName: key)
    }

    func setUserId(_ id: String?) {
        #if DEBUG
        print("[Analytics] setUserId: \(id ?? "nil")")
        #endif
        // Analytics.setUserID(id)
    }
}

// MARK: - ATT Service
@MainActor
final class ATTService {
    static let shared = ATTService()
    private init() {}

    private let attKey = "com.appfactory.ledgerfinance.attRequested"

    func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        let alreadyRequested = UserDefaults.standard.bool(forKey: attKey)
        guard !alreadyRequested else {
            return ATTrackingManager.trackingAuthorizationStatus
        }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        UserDefaults.standard.set(true, forKey: attKey)

        #if DEBUG
        print("[ATT] Authorization status: \(status.rawValue)")
        #endif

        return status
    }

    var isAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
}

// MARK: - Attribution Manager
@MainActor
final class AttributionManager {
    static let shared = AttributionManager()
    private init() {}

    private let attributionKey = "com.appfactory.ledgerfinance.attributionFetched"

    func requestAttributionIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: attributionKey) else { return }

        do {
            let token = try AAAttribution.attributionToken()
            UserDefaults.standard.set(true, forKey: attributionKey)

            // Send token to your server or use with Apple Search Ads API
            #if DEBUG
            print("[Attribution] Token obtained: \(token.prefix(20))...")
            #endif
        } catch {
            #if DEBUG
            print("[Attribution] Failed to get token: \(error)")
            #endif
        }
    }
}
