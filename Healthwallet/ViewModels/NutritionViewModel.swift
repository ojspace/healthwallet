import Foundation
import Observation

@Observable
@MainActor
final class NutritionViewModel {
    // MARK: - State

    var recommendations: NutritionRecommendationsResponse?
    var mealPlan: MealPlanResponse?
    var selectedTab: NutritionTab = .foods
    var selectedDay: Int = 1
    var isLoading = false
    var error: String?

    enum NutritionTab: String, CaseIterable {
        case foods = "Foods"
        case mealPlan = "Meal Plan"
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        recommendations?.has_data == true
    }

    var foods: [FoodRecommendation] {
        recommendations?.foods ?? []
    }

    var needs: [NutrientNeed] {
        recommendations?.needs ?? []
    }

    var recordDateFormatted: String? {
        guard let dateStr = recommendations?.record_date else { return nil }
        // Try to parse ISO date and format nicely
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            return date.formatted(.dateTime.month(.wide).day().year())
        }
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            return date.formatted(.dateTime.month(.wide).day().year())
        }
        return dateStr
    }

    var mealPlanDays: [MealPlanDay] {
        mealPlan?.plan ?? []
    }

    var selectedDayPlan: MealPlanDay? {
        mealPlanDays.first { $0.day == selectedDay }
    }

    var dietaryPreference: String? {
        recommendations?.dietary_preference ?? mealPlan?.dietary_preference
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        async let recsTask: Void = loadRecommendations()
        async let mealTask: Void = loadMealPlan()

        _ = await (recsTask, mealTask)
    }

    func loadRecommendations() async {
        do {
            let response: NutritionRecommendationsResponse = try await APIClient.shared.get(
                "/nutrition/recommendations"
            )
            recommendations = response
        } catch {
            self.error = "Could not load nutrition recommendations"
            print("[Nutrition] Recommendations error: \(error)")
        }
    }

    func loadMealPlan(days: Int = 7) async {
        do {
            let response: MealPlanResponse = try await APIClient.shared.get(
                "/nutrition/meal-plan?days=\(days)"
            )
            mealPlan = response
            // Default to first day if available
            if let firstDay = response.plan?.first {
                selectedDay = firstDay.day
            }
        } catch {
            if self.error == nil {
                self.error = "Could not load meal plan"
            }
            print("[Nutrition] Meal plan error: \(error)")
        }
    }
}
