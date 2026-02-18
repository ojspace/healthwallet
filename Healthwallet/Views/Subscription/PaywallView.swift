import SwiftUI
import RevenueCat
import RevenueCatUI

struct HealthWalletPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Group {
            if subscriptionManager.offerings?.current != nil {
                // Use RevenueCat's built-in PaywallView (configured in RC dashboard)
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        subscriptionManager.updateWith(customerInfo: customerInfo)
                        Task {
                            await subscriptionManager.checkSubscriptionStatus()
                            await AuthManager.shared.checkAuthStatus()
                        }
                        dismiss()
                    }
                    .onRestoreCompleted { customerInfo in
                        subscriptionManager.updateWith(customerInfo: customerInfo)
                        if subscriptionManager.isPro {
                            dismiss()
                        }
                    }
            } else {
                // Fallback paywall while offerings load or if no paywall configured in RC dashboard
                FallbackPaywallView(onDismiss: { dismiss() })
                    .task {
                        await subscriptionManager.fetchOfferings()
                    }
            }
        }
    }
}

// MARK: - Fallback Paywall (used before RC dashboard paywall is configured)

private struct FallbackPaywallView: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage: String?
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxxl) {
                    heroSection
                    featureComparison
                    priceSection
                    ctaButton
                    restoreButton
                    subscriptionTerms
                    legalLinks
                }
                .padding(AppTheme.Spacing.xxl)
            }
            .background(AppTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.Colors.primaryFallback, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock Your Full\nHealth Picture")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Get unlimited uploads, AI-powered supplement protocols, doctor-ready reports, and year-over-year tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var featureComparison: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feature").font(.caption.bold()).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free").font(.caption.bold()).foregroundStyle(.secondary).frame(width: 60)
                Text("Pro").font(.caption.bold()).foregroundStyle(AppTheme.Colors.primaryFallback).frame(width: 60)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.sm)
            Divider()

            featureRow("doc.fill", "PDF Uploads", "1", "Unlimited")
            featureRow("carrot.fill", "Food Recs", "Top 3", "All")
            featureRow("pills.fill", "Supplements", nil, "Yes")
            featureRow("doc.text.fill", "Doctor Brief", nil, "Yes")
            featureRow("chart.line.uptrend.xyaxis", "Trends", nil, "Yes")
        }
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    private func featureRow(_ icon: String, _ name: String, _ free: String?, _ pro: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: icon).font(.caption)
                        .foregroundStyle(AppTheme.Colors.primaryFallback).frame(width: 20)
                    Text(name).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if let free {
                        Text(free).font(.caption2).foregroundStyle(.orange)
                    } else {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.5))
                    }
                }.frame(width: 60)

                Group {
                    if pro == "Yes" {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Text(pro).font(.caption2.bold()).foregroundStyle(.green)
                    }
                }.frame(width: 60)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            Divider()
        }
    }

    private var priceSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let pkg = subscriptionManager.offerings?.current?.availablePackages.first {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pkg.storeProduct.localizedPriceString)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("/month").font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Text("Loading price...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("14-day free trial")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.primaryFallback)
                .clipShape(Capsule())
        }
    }

    private var ctaButton: some View {
        Button {
            Task { await purchaseAction() }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "crown.fill")
                }
                Text(isPurchasing ? "Processing..." : "Start Free Trial")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.primaryFallback, .purple.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
        .disabled(isPurchasing)
    }

    private var restoreButton: some View {
        Button {
            Task {
                let restored = await subscriptionManager.restorePurchases()
                if restored { onDismiss() }
                else {
                    errorMessage = "No purchases found to restore"
                    showError = true
                }
            }
        } label: {
            Text("Restore Purchases").font(.subheadline)
                .foregroundStyle(AppTheme.Colors.primaryFallback)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            Link("Terms of Service", destination: URL(string: "https://healthwallet.app/terms")!)
                .font(.caption2).foregroundStyle(.secondary)
            Link("Privacy Policy", destination: URL(string: "https://healthwallet.app/privacy")!)
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var subscriptionTerms: some View {
        Text("After the free trial, your subscription renews automatically unless canceled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account at confirmation of purchase. Manage or cancel in Settings > Apple ID > Subscriptions.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func purchaseAction() async {
        guard let pkg = subscriptionManager.offerings?.current?.availablePackages.first else {
            errorMessage = "No products available. Check your App Store Connect configuration."
            showError = true
            return
        }
        isPurchasing = true
        let success = await subscriptionManager.purchase(package: pkg)
        isPurchasing = false
        if success { onDismiss() }
        else if let err = subscriptionManager.error {
            errorMessage = err
            showError = true
        }
    }
}

#Preview {
    HealthWalletPaywallView()
}
