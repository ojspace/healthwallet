import Foundation

// MARK: - Nutrient Need

struct NutrientNeed: Codable, Identifiable, Sendable {
    let nutrient: String
    let reason: String
    let biomarker: String
    let status: String

    var id: String { nutrient + biomarker }

    var statusColor: String {
        switch status.lowercased() {
        case "low": return "statusLow"
        case "high": return "statusHigh"
        case "optimal": return "statusOptimal"
        default: return "statusLow"
        }
    }
}

// MARK: - Food Recommendation

struct FoodRecommendation: Codable, Identifiable, Sendable {
    let name: String
    let category: String
    let nutrients: [String]
    let why: String
    let serving: String
    let tags: [String]

    var id: String { name }

    var categoryIcon: String {
        switch category.lowercased() {
        case "protein": return "fish.fill"
        case "vegetable": return "leaf.fill"
        case "fruit": return "carrot.fill"
        case "grain": return "circle.grid.3x3.fill"
        case "fat": return "drop.fill"
        case "legume": return "oval.fill"
        case "dairy": return "cup.and.saucer.fill"
        default: return "fork.knife"
        }
    }

    var categoryColor: String {
        switch category.lowercased() {
        case "protein": return "blue"
        case "vegetable": return "green"
        case "fruit": return "orange"
        case "grain": return "brown"
        case "fat": return "yellow"
        case "legume": return "mint"
        case "dairy": return "cyan"
        default: return "gray"
        }
    }
}

// MARK: - Recommendations Response

struct NutritionRecommendationsResponse: Codable, Sendable {
    let has_data: Bool
    let record_date: String?
    let dietary_preference: String?
    let needs: [NutrientNeed]?
    let foods: [FoodRecommendation]?
    let total_unfiltered: Int?
    let message: String?
}

// MARK: - Meal Plan

struct MealPlanDay: Codable, Identifiable, Sendable {
    let day: Int
    let dayName: String
    let meals: [Meal]

    var id: Int { day }

    var shortDayName: String {
        String(dayName.prefix(3))
    }
}

struct Meal: Codable, Identifiable, Sendable {
    let type: String
    let foods: [FoodRecommendation]

    var id: String { type }

    var displayName: String {
        type.capitalized
    }

    var mealIcon: String {
        switch type.lowercased() {
        case "breakfast": return "sun.horizon.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "snack": return "cup.and.saucer.fill"
        default: return "fork.knife"
        }
    }

    var mealColor: String {
        switch type.lowercased() {
        case "breakfast": return "orange"
        case "lunch": return "yellow"
        case "dinner": return "indigo"
        case "snack": return "mint"
        default: return "gray"
        }
    }
}

struct MealPlanResponse: Codable, Sendable {
    let has_data: Bool
    let dietary_preference: String?
    let days_planned: Int?
    let plan: [MealPlanDay]?
    let message: String?
}
