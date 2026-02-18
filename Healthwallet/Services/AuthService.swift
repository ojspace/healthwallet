import Foundation

// MARK: - Auth DTOs

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case fullName = "full_name"
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - Dietary Preference (Epic 3)

enum DietaryPreference: String, Codable, CaseIterable {
    case omnivore
    case vegetarian
    case vegan
    case keto
    case paleo
    case pescatarian

    var displayName: String {
        switch self {
        case .omnivore: "Omnivore"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .keto: "Keto"
        case .paleo: "Paleo"
        case .pescatarian: "Pescatarian"
        }
    }

    var description: String {
        switch self {
        case .omnivore: "I eat everything"
        case .vegetarian: "No meat, but dairy & eggs OK"
        case .vegan: "Plant-based only"
        case .keto: "High fat, low carb"
        case .paleo: "Whole foods, no grains"
        case .pescatarian: "Fish & seafood, no meat"
        }
    }

    var icon: String {
        switch self {
        case .omnivore: "fork.knife"
        case .vegetarian: "leaf.fill"
        case .vegan: "leaf.circle.fill"
        case .keto: "flame.fill"
        case .paleo: "figure.hunting"
        case .pescatarian: "fish.fill"
        }
    }
}

// MARK: - Biological Sex

enum BiologicalSex: String, Codable, CaseIterable {
    case male
    case female
    case other

    var displayName: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .male: "figure.stand"
        case .female: "figure.stand.dress"
        case .other: "person.fill"
        }
    }
}

// MARK: - User Response

enum SubscriptionTier: String, Codable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        }
    }
}

struct UserResponse: Codable, Identifiable {
    let id: String
    let email: String
    let fullName: String?
    let isActive: Bool
    let dateOfBirth: Date?
    let biologicalSex: BiologicalSex?
    let dietaryPreference: DietaryPreference
    let allergies: [String]
    let healthGoals: [String]
    let healthConditions: [String]?
    let onboardingCompleted: Bool
    let age: Int?
    let subscriptionTier: SubscriptionTier?
    let subscriptionExpiresAt: Date?
    let uploadCount: Int?
    let canUpload: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, allergies, age
        case fullName = "full_name"
        case isActive = "is_active"
        case dateOfBirth = "date_of_birth"
        case biologicalSex = "biological_sex"
        case dietaryPreference = "dietary_preference"
        case healthGoals = "health_goals"
        case healthConditions = "health_conditions"
        case onboardingCompleted = "onboarding_completed"
        case subscriptionTier = "subscription_tier"
        case subscriptionExpiresAt = "subscription_expires_at"
        case uploadCount = "upload_count"
        case canUpload = "can_upload"
    }

    var isPro: Bool { subscriptionTier == .pro }
}

// MARK: - Profile Update (Epic 3)

struct ProfileUpdateRequest: Codable {
    let fullName: String?
    let dateOfBirth: Date?
    let biologicalSex: BiologicalSex?
    let dietaryPreference: DietaryPreference?
    let allergies: [String]?
    let healthGoals: [String]?
    let healthConditions: [String]?

    enum CodingKeys: String, CodingKey {
        case allergies
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case biologicalSex = "biological_sex"
        case dietaryPreference = "dietary_preference"
        case healthGoals = "health_goals"
        case healthConditions = "health_conditions"
    }
}

// MARK: - Onboarding Request

struct OnboardingRequest: Codable {
    let fullName: String?
    let dateOfBirth: Date?
    let biologicalSex: BiologicalSex?
    let dietaryPreference: DietaryPreference
    let allergies: [String]
    let healthGoals: [String]
    let healthConditions: [String]

    enum CodingKeys: String, CodingKey {
        case allergies
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case biologicalSex = "biological_sex"
        case dietaryPreference = "dietary_preference"
        case healthGoals = "health_goals"
        case healthConditions = "health_conditions"
    }
}

// MARK: - Auth Service

actor AuthService {
    static let shared = AuthService()
    private init() {}

    func register(email: String, password: String, fullName: String?) async throws -> UserResponse {
        let request = RegisterRequest(email: email, password: password, fullName: fullName)
        return try await APIClient.shared.post("/auth/register", body: request)
    }

    func login(email: String, password: String) async throws -> String {
        let formData = ["username": email, "password": password]
        let response: LoginResponse = try await APIClient.shared.postForm("/auth/login", formData: formData)
        await APIClient.shared.setToken(response.accessToken)
        return response.accessToken
    }

    func getCurrentUser() async throws -> UserResponse {
        return try await APIClient.shared.get("/auth/me")
    }

    func logout() async {
        await APIClient.shared.setToken(nil)
    }

    func deleteAccount() async throws {
        try await APIClient.shared.delete("/auth/account")
        await APIClient.shared.setToken(nil)
    }

    func isLoggedIn() async -> Bool {
        return await APIClient.shared.getToken() != nil
    }

    // MARK: - Epic 3: Profile & Onboarding

    func updateProfile(
        fullName: String? = nil,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex? = nil,
        dietaryPreference: DietaryPreference? = nil,
        allergies: [String]? = nil,
        healthGoals: [String]? = nil,
        healthConditions: [String]? = nil
    ) async throws -> UserResponse {
        let request = ProfileUpdateRequest(
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            dietaryPreference: dietaryPreference,
            allergies: allergies,
            healthGoals: healthGoals,
            healthConditions: healthConditions
        )
        return try await APIClient.shared.put("/profile", body: request)
    }

    func completeOnboarding(
        fullName: String?,
        dateOfBirth: Date?,
        biologicalSex: BiologicalSex?,
        dietaryPreference: DietaryPreference,
        allergies: [String],
        healthGoals: [String],
        healthConditions: [String]
    ) async throws -> UserResponse {
        let request = OnboardingRequest(
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            dietaryPreference: dietaryPreference,
            allergies: allergies,
            healthGoals: healthGoals,
            healthConditions: healthConditions
        )
        return try await APIClient.shared.post("/profile/onboarding", body: request)
    }
}
