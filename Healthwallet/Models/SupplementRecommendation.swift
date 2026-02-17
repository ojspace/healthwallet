import Foundation

struct SupplementRecommendation: Codable, Identifiable {
    var id: String { name }
    let name: String
    let dosage: String
    let reason: String
    let biomarkerLink: String
    let priority: String
    let keyword: String
    let keywordReason: String
    let timing: String
    let timingNote: String
    let amazonUrl: String
    let iherbUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, dosage, reason, priority, keyword, timing
        case biomarkerLink = "biomarker_link"
        case keywordReason = "keyword_reason"
        case timingNote = "timing_note"
        case amazonUrl = "amazon_url"
        case iherbUrl = "iherb_url"
    }

    var priorityIcon: String {
        switch priority {
        case "essential": return "exclamationmark.triangle.fill"
        case "recommended": return "hand.thumbsup.fill"
        default: return "sparkles"
        }
    }

    var priorityColor: String {
        switch priority {
        case "essential": return "red"
        case "recommended": return "orange"
        default: return "blue"
        }
    }

    var timingIcon: String {
        switch timing {
        case "morning_empty_stomach": return "sunrise.fill"
        case "morning_with_food": return "cup.and.saucer.fill"
        case "afternoon": return "sun.max.fill"
        case "evening_with_food": return "fork.knife"
        case "evening_before_bed": return "moon.fill"
        default: return "clock.fill"
        }
    }

    var timingDisplayName: String {
        switch timing {
        case "morning_empty_stomach": return "Morning (empty stomach)"
        case "morning_with_food": return "Morning (with food)"
        case "afternoon": return "Afternoon"
        case "evening_with_food": return "Evening (with food)"
        case "evening_before_bed": return "Before bed"
        default: return "As directed"
        }
    }

    /// Calendar hour for this timing slot
    var calendarHour: Int {
        switch timing {
        case "morning_empty_stomach": return 7
        case "morning_with_food": return 8
        case "afternoon": return 14
        case "evening_with_food": return 19
        case "evening_before_bed": return 22
        default: return 8
        }
    }
}

struct RecommendationsResponse: Codable {
    let recordId: String?
    let country: String
    let count: Int
    let recommendations: [SupplementRecommendation]

    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case country, count, recommendations
    }
}
