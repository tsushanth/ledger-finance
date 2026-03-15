//
//  LedgerFinanceApp.swift
//  LedgerFinance
//
//  Main app entry point with SwiftData, StoreKit 2, and SDK integrations
//

import SwiftUI
import SwiftData

@main
struct LedgerFinanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer
    @State private var storeKitManager = StoreKitManager()
    @State private var premiumManager = PremiumManager()

    init() {
        do {
            let schema = Schema([
                Transaction.self,
                Account.self,
                Category.self,
                Budget.self,
                BillReminder.self,
                NetWorthItem.self,
                NetWorthSnapshot.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(storeKitManager)
                .environment(premiumManager)
                .onAppear {
                    Task {
                        await premiumManager.refreshPremiumStatus(storeKit: storeKitManager)
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            AnalyticsService.shared.initialize()
            AnalyticsService.shared.track(.appOpen)
        }

        Task { @MainActor in
            _ = await ATTService.shared.requestIfNeeded()
            await AttributionManager.shared.requestAttributionIfNeeded()
        }

        return true
    }
}

// MARK: - Premium Manager
@MainActor
@Observable
final class PremiumManager {
    var isPremium: Bool = false
    var hasCompletedOnboarding: Bool = false

    private let premiumKey = "com.appfactory.ledgerfinance.isPremium"
    private let onboardingKey = "com.appfactory.ledgerfinance.onboardingComplete"

    init() {
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func refreshPremiumStatus(storeKit: StoreKitManager) async {
        await storeKit.updatePurchasedProducts()
        isPremium = storeKit.isPremium
        UserDefaults.standard.set(isPremium, forKey: premiumKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
        AnalyticsService.shared.track(.onboardingComplete)
    }

    // MARK: - Feature Gates
    func canAddTransaction(count: Int) -> Bool {
        isPremium || count < 50
    }

    var canAccessAllReports: Bool { isPremium }
    var canUseRecurringTransactions: Bool { isPremium }
    var canExportData: Bool { isPremium }
    var canSetBudgetGoals: Bool { isPremium }
    var canTrackNetWorth: Bool { isPremium }
    var unlimitedAccounts: Bool { isPremium }
}

// MARK: - Root View (handles onboarding gate)
struct RootView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @AppStorage("com.appfactory.ledgerfinance.onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
