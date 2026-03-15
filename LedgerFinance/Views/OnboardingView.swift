//
//  OnboardingView.swift
//  LedgerFinance
//
//  App onboarding flow
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(\.modelContext) private var modelContext

    @State private var currentPage: Int = 0
    @State private var showPaywall: Bool = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            iconColor: .blue,
            title: "Track Every Dollar",
            subtitle: "Easily log income and expenses. Know exactly where your money goes.",
            background: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)]
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: .orange,
            title: "Budget Smarter",
            subtitle: "Set spending limits by category and get alerts before you overspend.",
            background: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)]
        ),
        OnboardingPage(
            icon: "chart.pie.fill",
            iconColor: .purple,
            title: "Insightful Reports",
            subtitle: "Beautiful charts and reports show your spending trends at a glance.",
            background: [Color.purple.opacity(0.1), Color.indigo.opacity(0.05)]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: "Grow Your Net Worth",
            subtitle: "Track assets and liabilities. Watch your wealth build over time.",
            background: [Color.green.opacity(0.1), Color.teal.opacity(0.05)]
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: pages[currentPage].background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicators
                pageIndicators

                // Action button
                actionButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: "onboarding")
        }
        .onAppear {
            AnalyticsService.shared.track(.onboardingStart)
            setupDefaultData()
        }
    }

    // MARK: - Page Indicators
    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.4))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(), value: currentPage)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Action Button
    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation { currentPage += 1 }
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
    }

    // MARK: - Setup Default Data
    private func setupDefaultData() {
        // Insert default categories if none exist
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.isSystem })
        let existingCategories = (try? modelContext.fetch(descriptor)) ?? []

        guard existingCategories.isEmpty else { return }

        for category in Category.allDefaultCategories {
            modelContext.insert(category)
        }

        // Insert default account
        let accDescriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? modelContext.fetch(accDescriptor)) ?? []

        if existingAccounts.isEmpty {
            let defaultAccount = Account(
                name: "Main Checking",
                type: .checking,
                balance: 0,
                isDefault: true
            )
            modelContext.insert(defaultAccount)
        }
    }

    private func completeOnboarding() {
        premiumManager.completeOnboarding()
        UserDefaults.standard.set(true, forKey: "com.appfactory.ledgerfinance.onboardingComplete")
    }
}

// MARK: - Onboarding Page Data
struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let background: [Color]
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Circle()
                .fill(page.iconColor.opacity(0.15))
                .frame(width: 140, height: 140)
                .overlay {
                    Image(systemName: page.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(page.iconColor)
                }
                .shadow(color: page.iconColor.opacity(0.3), radius: 20, y: 8)

            // Text
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView()
        .environment(PremiumManager())
        .environment(StoreKitManager())
        .modelContainer(for: [
            Transaction.self, Account.self, Category.self, Budget.self,
            BillReminder.self, NetWorthItem.self, NetWorthSnapshot.self
        ], inMemory: true)
}
