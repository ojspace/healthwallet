import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    var isAuthenticated = false
    var currentUser: UserResponse?
    var isLoading = false
    /// True only during the app's initial auth bootstrap.
    /// We keep this separate from `isLoading` so interactive actions (e.g. sign-in)
    /// don't replace the login screen with a full-screen splash.
    var isBootstrapping = true
    var error: String?
    var needsOnboarding: Bool {
        guard let user = currentUser else { return false }
        return !user.onboardingCompleted
    }

    private init() {
        Task {
            await checkAuthStatus()
        }
    }

    func checkAuthStatus() async {
        isLoading = true
        defer {
            isLoading = false
            isBootstrapping = false
        }

        let hasToken = await AuthService.shared.isLoggedIn()

        if hasToken {
            do {
                currentUser = try await AuthService.shared.getCurrentUser()
                isAuthenticated = true
                // Sync RevenueCat
                if let userId = currentUser?.id {
                    await SubscriptionManager.shared.login(appUserID: userId)
                }
                await SubscriptionManager.shared.checkSubscriptionStatus()
            } catch {
                isAuthenticated = false
                currentUser = nil
            }
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            print("[AUTH] Starting login for \(email)...")
            _ = try await AuthService.shared.login(email: email, password: password)
            print("[AUTH] Login token received, fetching user...")
            currentUser = try await AuthService.shared.getCurrentUser()
            print("[AUTH] User fetched: \(currentUser?.email ?? "nil"), setting authenticated=true")
            isAuthenticated = true

            // Sync RevenueCat user ID
            if let userId = currentUser?.id {
                await SubscriptionManager.shared.login(appUserID: userId)
            }
        } catch let apiError as APIError {
            print("[AUTH] APIError: \(apiError.localizedDescription)")
            error = apiError.localizedDescription
            throw apiError
        } catch {
            print("[AUTH] Error: \(error)")
            self.error = "Login failed: \(error)"
            throw error
        }
    }

    func register(email: String, password: String, fullName: String?) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            _ = try await AuthService.shared.register(email: email, password: password, fullName: fullName)
            // Auto-login after registration
            try await login(email: email, password: password)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            throw apiError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func signInWithApple() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await AppleSignInManager.shared.signIn()
            // AppleSignInManager already updates currentUser and isAuthenticated
        } catch let appleError as AppleSignInError {
            if case .canceled = appleError { return } // Don't show error for cancel
            error = appleError.localizedDescription
            throw appleError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func logout() async {
        await SubscriptionManager.shared.logout()
        await AuthService.shared.logout()
        isAuthenticated = false
        currentUser = nil
    }

    func deleteAccount() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await AuthService.shared.deleteAccount()
            await logout()
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            throw apiError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func completeOnboarding(
        fullName: String?,
        dateOfBirth: Date?,
        biologicalSex: BiologicalSex?,
        dietaryPreference: DietaryPreference,
        allergies: [String],
        healthGoals: [String],
        healthConditions: [String]
    ) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentUser = try await AuthService.shared.completeOnboarding(
                fullName: fullName,
                dateOfBirth: dateOfBirth,
                biologicalSex: biologicalSex,
                dietaryPreference: dietaryPreference,
                allergies: allergies,
                healthGoals: healthGoals,
                healthConditions: healthConditions
            )
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            throw apiError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func updateProfile(
        fullName: String? = nil,
        biologicalSex: BiologicalSex? = nil,
        dietaryPreference: DietaryPreference? = nil,
        allergies: [String]? = nil,
        healthGoals: [String]? = nil,
        healthConditions: [String]? = nil
    ) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentUser = try await AuthService.shared.updateProfile(
                fullName: fullName,
                biologicalSex: biologicalSex,
                dietaryPreference: dietaryPreference,
                allergies: allergies,
                healthGoals: healthGoals,
                healthConditions: healthConditions
            )
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            throw apiError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
}
