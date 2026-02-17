import Foundation

enum SampleData {
    static let vitaminD = Biomarker(
        name: "Vitamin D",
        value: 24,
        unit: "ng/mL",
        status: .low,
        optimalRange: 30...80,
        description: "Vitamin D is crucial for bone health, immune function, and mood. Your level of 24 ng/mL is considered insufficient, which is very common.",
        whyItMatters: [
            "Linked to lower energy levels.",
            "Important for long-term bone density.",
            "Plays a role in immune system regulation."
        ],
        foodFixes: [
            FoodFix(name: "Cod Liver Oil", portion: "1 tbsp", iconName: "cross.vial.fill"),
            FoodFix(name: "Sockeye Salmon", portion: "3 oz", iconName: "fish.fill"),
            FoodFix(name: "Fortified Milk / Plant Milk", portion: "1 cup", iconName: "cup.and.saucer.fill"),
        ]
    )

    static let ldlCholesterol = Biomarker(
        name: "LDL Cholesterol",
        value: 155,
        unit: "mg/dL",
        status: .high,
        optimalRange: 0...100
    )

    static let fastingGlucose = Biomarker(
        name: "Fasting Glucose",
        value: 85,
        unit: "mg/dL",
        status: .optimal,
        optimalRange: 70...100
    )

    static let biomarkers = [vitaminD, ldlCholesterol, fastingGlucose]

    static let records: [HealthRecord] = [
        HealthRecord(
            title: "Blood Panel",
            date: date(2023, 10, 26),
            provider: "Quest Diagnostics",
            type: .bloodPanel,
            biomarkers: biomarkers
        ),
        HealthRecord(
            title: "Annual Physical",
            date: date(2023, 1, 15),
            provider: "Dr. Smith",
            type: .annualPhysical
        ),
        HealthRecord(
            title: "Hormone Panel",
            date: date(2022, 1, 25),
            provider: "LabCorp",
            type: .hormonePanel
        ),
    ]

    static let weeklyFocusItems: [WeeklyFocus] = [
        WeeklyFocus(
            title: "Add Salmon",
            subtitle: "2x this week for Omega-3s",
            actionLabel: "See Recipe",
            imageURL: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuBM6_yz-PG0IL2uoJUOBr4yA__A_LE5YKGKVjHgKreUBx0An65BLUHi4qAVQaWvnuZavcy9uis--h8ImfmAwADzaEGjWEvh80y9pYKQyHpKaPohqLv5pYkicB6HFmC4FyvmWR03qvGDWxCtuNDSTVLQVMGItdHkoD4NAoMZ47WalMZJb1R2DKWhxeMv-iFWS2Pe1YXn678ApHqnnKIbe-bj_IVwbk3lotKxGxtB5KsYq8JVUHpRSznvNNyteRRYTP3XEc9u3mnQCAY9")
        ),
        WeeklyFocus(
            title: "Morning Sunlight",
            subtitle: "15 mins before 10 AM",
            iconName: "sun.max.fill",
            actionLabel: "Set Reminder"
        ),
        WeeklyFocus(
            title: "Take Vitamin D3",
            subtitle: "2000 IU daily with food",
            iconName: "pills.fill",
            actionLabel: "Log Dose"
        ),
    ]

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
