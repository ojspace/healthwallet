import Foundation

// MARK: - API Response

struct WeeklyFocusResponse: Codable {
    let items: [WeeklyFocusItem]
    let summary: String
}

struct WeeklyFocusItem: Codable {
    let title: String
    let subtitle: String
    let iconName: String
    let actionLabel: String
    let actionType: String
    let reminderName: String?
    let reminderTiming: String?
    let reminderHour: Int?

    enum CodingKeys: String, CodingKey {
        case title, subtitle
        case iconName = "icon_name"
        case actionLabel = "action_label"
        case actionType = "action_type"
        case reminderName = "reminder_name"
        case reminderTiming = "reminder_timing"
        case reminderHour = "reminder_hour"
    }
}

// MARK: - Local Model

enum FocusActionType: String, Hashable {
    case reminder   // Wire to CalendarManager
    case recipe     // Open Chat with recipe prompt
    case activity   // Open Chat with activity prompt
    case tip        // Show inline tip
}

struct WeeklyFocus: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let iconName: String
    let actionLabel: String
    let actionType: FocusActionType
    let imageURL: URL?
    // For reminder actions — supplement data
    let reminderName: String?
    let reminderTiming: String?
    let reminderHour: Int?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        iconName: String = "",
        actionLabel: String,
        actionType: FocusActionType = .tip,
        imageURL: URL? = nil,
        reminderName: String? = nil,
        reminderTiming: String? = nil,
        reminderHour: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionLabel = actionLabel
        self.actionType = actionType
        self.imageURL = imageURL
        self.reminderName = reminderName
        self.reminderTiming = reminderTiming
        self.reminderHour = reminderHour
    }
}
