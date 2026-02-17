import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - State

    var isPro = false
    var customerInfo: CustomerInfo?
    var offerings: Offerings?
    var isLoading = false
    var error: String?

    var canUpload: Bool {
        isPro || (AuthManager.shared.currentUser?.uploadCount ?? 0) < 1
    }

    // MARK: - Constants

    static let entitlementID = "pro"
    static let productID = "healthwallet_pro_monthly"

    // MARK: - Init

    private init() {
        // Delegate is configured in HealthwalletApp after Purchases.configure().
    }

    // MARK: - Login / Logout (sync with auth)

    func login(appUserID: String) async {
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            updateWith(customerInfo: info)
            // Link RevenueCat ID to backend
            try? await linkToBackend(revenueCatID: info.originalAppUserId)
        } catch {
            print("[RC] Login error: \(error)")
        }
    }

    func logout() async {
        do {
            let info = try await Purchases.shared.logOut()
            updateWith(customerInfo: info)
        } catch {
            print("[RC] Logout error: \(error)")
        }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            self.error = "Failed to load subscription options"
            print("[RC] Offerings error: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if !result.userCancelled {
                updateWith(customerInfo: result.customerInfo)
                // Sync to backend
                try? await syncToBackend()
                return true
            }
            return false
        } catch {
            self.error = error.localizedDescription
            print("[RC] Purchase error: \(error)")
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            updateWith(customerInfo: info)
            try? await syncToBackend()
            return isPro
        } catch {
            self.error = "No purchases found to restore"
            print("[RC] Restore error: \(error)")
            return false
        }
    }

    // MARK: - Check Status

    func checkSubscriptionStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateWith(customerInfo: info)
        } catch {
            print("[RC] CustomerInfo error: \(error)")
        }
    }

    // MARK: - Update State

    func updateWith(customerInfo info: CustomerInfo) {
        customerInfo = info
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
        print("[RC] Updated — isPro: \(isPro)")
    }

    // MARK: - Backend Sync

    private func linkToBackend(revenueCatID: String) async throws {
        struct LinkRequest: Codable {
            let revenuecatId: String
            enum CodingKeys: String, CodingKey {
                case revenuecatId = "revenuecat_id"
            }
        }
        struct LinkResponse: Codable {
            let status: String
        }

        let _: LinkResponse = try await APIClient.shared.post(
            "/subscription/verify-receipt",
            body: LinkRequest(revenuecatId: revenueCatID)
        )
    }

    private func syncToBackend() async throws {
        // Refresh user profile from backend to sync subscription state
        await AuthManager.shared.checkAuthStatus()
    }
}

// MARK: - RevenueCat Delegate

final class RevenueCatDelegate: NSObject, PurchasesDelegate, Sendable {
    static let shared = RevenueCatDelegate()

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionManager.shared.updateWith(customerInfo: customerInfo)
        }
    }
}
