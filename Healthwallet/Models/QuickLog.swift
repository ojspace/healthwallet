import Foundation

struct QuickLog: Codable {
    let mood: Int // 1-5
    let energy: Int // 1-5
    let symptoms: [String]
    let notes: String?
    let loggedAt: Date?
    let date: String? // YYYY-MM-DD from backend

    enum CodingKeys: String, CodingKey {
        case mood, energy, symptoms, notes
        case loggedAt = "logged_at"
        case date
    }
}

struct QuickLogResponse: Codable {
    let mood: Int
    let energy: Int
    let symptoms: [String]
    let notes: String?
    let date: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case mood, energy, symptoms, notes, date
        case createdAt = "created_at"
    }
}

struct QuickLogListResponse: Codable {
    let daysRequested: Int
    let count: Int
    let logs: [QuickLogResponse]

    enum CodingKeys: String, CodingKey {
        case daysRequested = "days_requested"
        case count, logs
    }
}

struct QuickLogPostResponse: Codable {
    let status: String
    let date: String
}

struct StreakResponse: Codable {
    let currentStreak: Int
    let longestStreak: Int

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
    }
}
