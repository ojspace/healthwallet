import Foundation
import AuthenticationServices
import Observation

// MARK: - Request / Response DTOs

struct AppleSignInRequest: Codable {
    let identityToken: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case fullName = "full_name"
    }
}

struct AppleAuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: AppleAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}

struct AppleAuthUser: Codable {
    let id: String
    let email: String
    let fullName: String?
    let subscriptionTier: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case subscriptionTier = "subscription_tier"
        case onboardingCompleted = "onboarding_completed"
    }
}

// MARK: - Apple Sign-In Manager

@Observable
@MainActor
final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()

    var isProcessing = false
    var error: String?

    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    private override init() {
        super.init()
    }

    func signIn() async throws {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        do {
            let authorization = try await performAppleSignIn()

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                throw AppleSignInError.invalidCredential
            }

            // Build full name from components (only available on first sign-in)
            var fullName: String? = nil
            if let nameComponents = credential.fullName {
                let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
                if !parts.isEmpty {
                    fullName = parts.joined(separator: " ")
                }
            }

            // Send identity token to backend
            let request = AppleSignInRequest(identityToken: identityToken, fullName: fullName)
            let response: AppleAuthResponse = try await APIClient.shared.post("/auth/apple", body: request)

            // Store JWT token
            await APIClient.shared.setToken(response.accessToken)

            // Fetch full user profile using existing flow
            let user: UserResponse = try await APIClient.shared.get("/auth/me")

            // Update shared auth state
            AuthManager.shared.currentUser = user
            AuthManager.shared.isAuthenticated = true

            // Sync RevenueCat
            await SubscriptionManager.shared.login(appUserID: user.id)
            await SubscriptionManager.shared.checkSubscriptionStatus()

        } catch let appleError as AppleSignInError {
            error = appleError.localizedDescription
            throw appleError
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    private func performAppleSignIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            signInContinuation?.resume(returning: authorization)
            signInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                signInContinuation?.resume(throwing: AppleSignInError.canceled)
            } else {
                signInContinuation?.resume(throwing: AppleSignInError.authorizationFailed(error.localizedDescription))
            }
            signInContinuation = nil
        }
    }
}

// MARK: - Error Type

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case canceled
    case authorizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Could not get Apple credentials"
        case .canceled:
            return "Sign in was canceled"
        case .authorizationFailed(let message):
            return "Apple Sign-In failed: \(message)"
        }
    }
}
