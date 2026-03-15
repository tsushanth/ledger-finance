//
//  PaywallView.swift
//  LedgerFinance
//
//  Premium subscription paywall
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    let source: String

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(PremiumManager.self) private var premiumManager

    @State private var selectedProduct: Product?
    @State private var isPurchasing: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let features: [PremiumFeature] = [
        .init(icon: "infinity", title: "Unlimited Transactions", description: "Track as many transactions as you need"),
        .init(icon: "chart.pie.fill", title: "All Reports & Charts", description: "Full access to spending reports and analytics"),
        .init(icon: "repeat.circle.fill", title: "Recurring Transactions", description: "Auto-schedule recurring income & expenses"),
        .init(icon: "target", title: "Budget Goals", description: "Set savings goals and track progress"),
        .init(icon: "chart.line.uptrend.xyaxis", title: "Net Worth Tracking", description: "Monitor assets & liabilities over time"),
        .init(icon: "square.and.arrow.up", title: "CSV & PDF Export", description: "Export your data in multiple formats"),
        .init(icon: "creditcard.fill", title: "Unlimited Accounts", description: "Add all your bank & credit card accounts"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Products
                    productsSection

                    // CTA
                    ctaSection

                    // Footer
                    footerSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(paywallGradient)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restore") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: storeKit.purchaseState) { _, newState in
                switch newState {
                case .purchased:
                    Task {
                        await premiumManager.refreshPremiumStatus(storeKit: storeKit)
                        dismiss()
                    }
                case .failed(let msg):
                    errorMessage = msg
                    showError = true
                    isPurchasing = false
                default:
                    isPurchasing = false
                }
            }
            .onAppear {
                AnalyticsService.shared.track(.paywallViewed(source: source))
                if selectedProduct == nil {
                    selectedProduct = storeKit.subscriptions.first(where: { $0.isPopular }) ?? storeKit.subscriptions.last
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.5), radius: 12)

            Text("Ledger Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Take full control of your finances")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 20)
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(features) { feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 10)

                if feature.id != features.last?.id {
                    Divider()
                        .background(.white.opacity(0.15))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Products
    private var productsSection: some View {
        VStack(spacing: 10) {
            if storeKit.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding()
            } else if storeKit.subscriptions.isEmpty {
                Text("Products loading...")
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
            } else {
                ForEach(storeKit.subscriptions) { product in
                    productCard(product)
                }

                // Lifetime option
                ForEach(storeKit.nonConsumables) { product in
                    productCard(product)
                }
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if product.isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }

                    if let savings = product.savingsLabel {
                        Text(savings)
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(product.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
            .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA
    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                purchaseSelected()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.blue)
                    } else {
                        Text("Start Premium")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedProduct == nil || isPurchasing)

            Text("Cancel anytime · Secure payment")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Link("Privacy Policy", destination: URL(string: "https://appfactory.com/privacy")!)
                Link("Terms of Use", destination: URL(string: "https://appfactory.com/terms")!)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))

            Text("Subscriptions auto-renew unless cancelled 24 hours before renewal. Manage in App Store settings.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var paywallGradient: some View {
        LinearGradient(
            colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Purchase
    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        AnalyticsService.shared.track(.purchaseStarted(productID: product.id))

        Task {
            do {
                _ = try await storeKit.purchase(product)
                AnalyticsService.shared.track(.purchaseCompleted(productID: product.id))
            } catch StoreKitError.userCancelled {
                AnalyticsService.shared.track(.purchaseCancelled)
            } catch {
                AnalyticsService.shared.track(.purchaseFailed(reason: error.localizedDescription))
            }
        }
    }
}

// MARK: - Premium Feature
struct PremiumFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

#Preview {
    PaywallView(source: "preview")
        .environment(StoreKitManager())
        .environment(PremiumManager())
}
