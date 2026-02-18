import Foundation
import HealthKit
import Observation
import SwiftUI

// MARK: - Chat Message Model

struct OnboardingBubble: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isBot: Bool
    let step: Int

    static func == (lhs: OnboardingBubble, rhs: OnboardingBubble) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case healthKit = 1
    case name = 2
    case dateOfBirth = 3
    case biologicalSex = 4
    case healthGoals = 5
    case dietaryPreference = 6
    case allergies = 7
    case healthConditions = 8
    case summary = 9

    var totalSteps: Int { Self.allCases.count }

    var progress: Double {
        Double(rawValue) / Double(totalSteps - 1)
    }

    var botMessage: String {
        switch self {
        case .welcome:
            return "Welcome to HealthWallet! I'll help you set up your profile so we can personalize your health insights."
        case .healthKit:
            return "" // Full-screen view, no chat bubble needed
        case .name:
            return "What should I call you?"
        case .dateOfBirth:
            return "When were you born?"
        case .biologicalSex:
            return "What is your biological sex? This helps us interpret your biomarker ranges accurately."
        case .healthGoals:
            return "What are your health goals? Select all that apply."
        case .dietaryPreference:
            return "What are your dietary preferences?"
        case .allergies:
            return "Any food allergies we should know about?"
        case .healthConditions:
            return "Do you have any existing health conditions?"
        case .summary:
            return "Here's your profile summary. Ready to get started?"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step State

    var currentStep: OnboardingStep = .welcome
    var messages: [OnboardingBubble] = []
    var isShowingInput = false
    var isTyping = false

    // MARK: - HealthKit Smart Skip

    var healthKitConnected = false

    // MARK: - User Answers

    var name: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    var showDatePicker = false
    var biologicalSex: BiologicalSex?
    var healthGoals: Set<String> = []
    var dietaryPreference: DietaryPreference?
    var allergies: Set<String> = []
    var customAllergy: String = ""
    var healthConditions: Set<String> = []
    var customCondition: String = ""

    // MARK: - Submission State

    var isSubmitting = false
    var errorMessage: String?
    var showError = false

    // MARK: - Options

    let availableGoals = [
        "Weight Loss", "Better Sleep", "More Energy", "Build Muscle",
        "Heart Health", "Longevity", "Gut Health", "Mental Clarity"
    ]

    let availableAllergies = [
        "Dairy", "Gluten", "Nuts", "Shellfish", "Soy", "Eggs"
    ]

    let availableConditions = [
        "Diabetes", "Hypertension", "Thyroid", "Anemia", "High Cholesterol", "None"
    ]

    // MARK: - Computed

    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Steps to skip when HealthKit is connected (we get DOB/sex from HK)
    private var skippedSteps: Set<OnboardingStep> {
        healthKitConnected ? [.name, .dateOfBirth, .biologicalSex] : []
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .healthKit:
            return true
        case .name:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .dateOfBirth:
            return true
        case .biologicalSex:
            return biologicalSex != nil
        case .healthGoals:
            return !healthGoals.isEmpty
        case .dietaryPreference:
            return dietaryPreference != nil
        case .allergies:
            return true
        case .healthConditions:
            return true
        case .summary:
            return true
        }
    }

    var userReplyText: String? {
        switch currentStep {
        case .welcome, .healthKit, .summary:
            return nil
        case .name:
            return name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name
        case .dateOfBirth:
            return dateOfBirth.formatted(.dateTime.month(.wide).day().year())
        case .biologicalSex:
            return biologicalSex?.displayName
        case .healthGoals:
            return healthGoals.isEmpty ? nil : healthGoals.sorted().joined(separator: ", ")
        case .dietaryPreference:
            return dietaryPreference?.displayName
        case .allergies:
            let all = combinedAllergies
            return all.isEmpty ? "No allergies" : all.joined(separator: ", ")
        case .healthConditions:
            let all = combinedConditions
            return all.isEmpty ? "No conditions" : all.joined(separator: ", ")
        }
    }

    var combinedAllergies: [String] {
        var result = Array(allergies)
        let trimmed = customAllergy.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result.append(trimmed)
        }
        return result
    }

    var combinedConditions: [String] {
        var result = Array(healthConditions.filter { $0 != "None" })
        let trimmed = customCondition.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            result.append(trimmed)
        }
        return result
    }

    // MARK: - Icon Helpers

    func iconForGoal(_ goal: String) -> String {
        switch goal {
        case "Weight Loss": return "scalemass.fill"
        case "Better Sleep": return "moon.fill"
        case "More Energy": return "bolt.fill"
        case "Build Muscle": return "figure.strengthtraining.traditional"
        case "Heart Health": return "heart.fill"
        case "Longevity": return "hourglass"
        case "Gut Health": return "leaf.fill"
        case "Mental Clarity": return "brain.head.profile"
        default: return "star.fill"
        }
    }

    func iconForAllergy(_ allergy: String) -> String {
        switch allergy {
        case "Dairy": return "cup.and.saucer.fill"
        case "Gluten": return "allergens"
        case "Nuts": return "tree.fill"
        case "Shellfish": return "fish.fill"
        case "Soy": return "leaf.circle.fill"
        case "Eggs": return "circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    func iconForCondition(_ condition: String) -> String {
        switch condition {
        case "Diabetes": return "drop.fill"
        case "Hypertension": return "heart.fill"
        case "Thyroid": return "waveform.path.ecg"
        case "Anemia": return "cross.fill"
        case "High Cholesterol": return "chart.line.uptrend.xyaxis"
        case "None": return "checkmark.circle.fill"
        default: return "staroflife.fill"
        }
    }

    // MARK: - Navigation

    func start() {
        addBotMessage(for: .welcome)
    }

    /// Called when HealthKit connects successfully — extract profile data from HK
    func onHealthKitConnected() {
        healthKitConnected = true
        let hkManager = HealthKitManager.shared

        // Try to extract DOB from HealthKit
        if let hkDOB = hkManager.getDateOfBirth() {
            dateOfBirth = hkDOB
        }

        // Try to extract biological sex from HealthKit
        if let hkSex = hkManager.getBiologicalSex() {
            switch hkSex {
            case .male: biologicalSex = .male
            case .female: biologicalSex = .female
            case .other: biologicalSex = .other
            default: break
            }
        }

        // Add a confirmation bubble, then advance
        let confirmMsg = OnboardingBubble(
            text: "Apple Health connected! I've synced your health data.",
            isBot: true,
            step: OnboardingStep.healthKit.rawValue
        )
        withAnimation(.spring(duration: 0.35)) {
            messages.append(confirmMsg)
        }

        // Jump to next non-skipped step
        advanceFromHealthKit()
    }

    /// Called when HealthKit is skipped
    func onHealthKitSkipped() {
        healthKitConnected = false
        advanceFromHealthKit()
    }

    private func advanceFromHealthKit() {
        // Find next step after healthKit, skipping any that should be skipped
        var nextRaw = OnboardingStep.healthKit.rawValue + 1
        while let step = OnboardingStep(rawValue: nextRaw), skippedSteps.contains(step) {
            nextRaw += 1
        }
        guard let nextStep = OnboardingStep(rawValue: nextRaw) else { return }

        currentStep = nextStep
        isShowingInput = false
        showTypingThenMessage(for: nextStep)
    }

    func advanceStep() {
        guard canProceed else { return }

        // Add the user's reply bubble for the current step
        if let reply = userReplyText {
            let userMsg = OnboardingBubble(text: reply, isBot: false, step: currentStep.rawValue)
            withAnimation(.spring(duration: 0.35)) {
                messages.append(userMsg)
            }
        }

        // Find the next non-skipped step
        var nextRaw = currentStep.rawValue + 1
        while let step = OnboardingStep(rawValue: nextRaw), skippedSteps.contains(step) {
            nextRaw += 1
        }
        guard let nextStep = OnboardingStep(rawValue: nextRaw) else { return }

        currentStep = nextStep
        isShowingInput = false

        // HealthKit step is full-screen, handled separately
        if nextStep == .healthKit {
            isShowingInput = true
            return
        }

        showTypingThenMessage(for: nextStep)
    }

    func goBack() {
        guard currentStep.rawValue > 0 else { return }

        // Remove messages for current step and previous user reply
        withAnimation(.spring(duration: 0.3)) {
            messages.removeAll { $0.step >= currentStep.rawValue }
            if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                messages.removeAll { !$0.isBot && $0.step == prevStep.rawValue }
            }
        }

        // Find previous non-skipped step
        var prevRaw = currentStep.rawValue - 1
        while let step = OnboardingStep(rawValue: prevRaw), skippedSteps.contains(step) {
            prevRaw -= 1
        }

        guard let prevStep = OnboardingStep(rawValue: prevRaw), prevRaw >= 0 else { return }
        currentStep = prevStep
        isShowingInput = true
        isTyping = false
    }

    // MARK: - Submission

    func submitOnboarding(authManager: AuthManager) async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await authManager.completeOnboarding(
                fullName: name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name.trimmingCharacters(in: .whitespaces),
                dateOfBirth: dateOfBirth,
                biologicalSex: biologicalSex,
                dietaryPreference: dietaryPreference ?? .omnivore,
                allergies: combinedAllergies,
                healthGoals: Array(healthGoals),
                healthConditions: combinedConditions
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    private func addBotMessage(for step: OnboardingStep) {
        let msg = OnboardingBubble(text: step.botMessage, isBot: true, step: step.rawValue)
        withAnimation(.spring(duration: 0.35)) {
            messages.append(msg)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.35)) {
                isShowingInput = true
            }
        }
    }

    private func showTypingThenMessage(for step: OnboardingStep) {
        isTyping = true

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isTyping = false
            addBotMessage(for: step)
        }
    }

    // MARK: - Allergy / Condition Toggle Helpers

    func toggleAllergy(_ allergy: String) {
        if allergies.contains(allergy) {
            allergies.remove(allergy)
        } else {
            allergies.insert(allergy)
        }
    }

    func toggleCondition(_ condition: String) {
        if condition == "None" {
            healthConditions = ["None"]
            return
        }
        healthConditions.remove("None")
        if healthConditions.contains(condition) {
            healthConditions.remove(condition)
        } else {
            healthConditions.insert(condition)
        }
    }

    func toggleGoal(_ goal: String) {
        if healthGoals.contains(goal) {
            healthGoals.remove(goal)
        } else {
            healthGoals.insert(goal)
        }
    }
}
