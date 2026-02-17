import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let role: String
    let content: String
    let created_at: String

    var isUser: Bool { role == "user" }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try multiple formats from the backend
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: created_at) {
                let display = DateFormatter()
                display.timeStyle = .short
                return display.string(from: date)
            }
        }
        return ""
    }

    /// Creates a local user message before the server responds.
    static func localUserMessage(content: String) -> ChatMessage {
        ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: content,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Creates a placeholder message shown while the AI is "typing".
    static func typingIndicator() -> ChatMessage {
        ChatMessage(
            id: "typing-indicator",
            role: "assistant",
            content: "",
            created_at: ISO8601DateFormatter().string(from: Date())
        )
    }
}

struct ChatResponse: Codable {
    let id: String
    let role: String
    let content: String
    let created_at: String

    func toChatMessage() -> ChatMessage {
        ChatMessage(id: id, role: role, content: content, created_at: created_at)
    }
}

struct ChatHistoryResponse: Codable {
    let messages: [ChatMessage]
    let has_more: Bool
    let cursor: String?
}

struct ChatSuggestion: Codable, Identifiable {
    let text: String
    let icon: String

    var id: String { text }
}

struct ChatSuggestionsResponse: Codable {
    let suggestions: [ChatSuggestion]
}

struct ChatSendBody: Codable {
    let message: String
}
