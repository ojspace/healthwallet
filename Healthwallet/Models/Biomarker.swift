import Foundation

struct Biomarker: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let value: Double
    let unit: String
    let status: BiomarkerStatus
    let optimalRange: ClosedRange<Double>
    let description: String
    let whyItMatters: [String]
    let foodFixes: [FoodFix]

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String,
        status: BiomarkerStatus,
        optimalRange: ClosedRange<Double>,
        description: String = "",
        whyItMatters: [String] = [],
        foodFixes: [FoodFix] = []
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.status = status
        self.optimalRange = optimalRange
        self.description = description
        self.whyItMatters = whyItMatters
        self.foodFixes = foodFixes
    }
}

struct FoodFix: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let portion: String
    let iconName: String

    init(id: UUID = UUID(), name: String, portion: String, iconName: String) {
        self.id = id
        self.name = name
        self.portion = portion
        self.iconName = iconName
    }
}
