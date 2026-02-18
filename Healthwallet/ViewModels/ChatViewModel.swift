import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    // MARK: - State

    private(set) var messages: [ChatMessage] = []
    private(set) var suggestions: [ChatSuggestion] = []
    var inputText: String = ""
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var isLoadingMore = false
    private(set) var error: String?
    private(set) var scrollToBottomTrigger: UUID?

    // Pagination
    private var cursor: String?
    private var hasMore = false

    // MARK: - Computed

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var showSuggestions: Bool {
        !suggestions.isEmpty && messages.isEmpty
    }

    func clearError() {
        error = nil
    }

    // MARK: - Load Initial Data

    func loadInitialData() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadHistory() }
            group.addTask { await self.loadSuggestions() }
        }
    }

    // MARK: - Chat History

    func loadHistory() async {
        do {
            let response: ChatHistoryResponse = try await APIClient.shared.get("/chat/history?limit=50")
            messages = response.messages.reversed()
            hasMore = response.has_more
            cursor = response.cursor
            scrollToBottom()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMoreHistory() async {
        guard hasMore, !isLoadingMore, let cursor = cursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response: ChatHistoryResponse = try await APIClient.shared.get(
                "/chat/history?limit=50&before=\(cursor)"
            )
            let older = response.messages.reversed()
            messages.insert(contentsOf: older, at: 0)
            hasMore = response.has_more
            self.cursor = response.cursor
        } catch {
            // Silently fail for pagination
        }
    }

    // MARK: - Suggestions

    func loadSuggestions() async {
        do {
            let response: ChatSuggestionsResponse = try await APIClient.shared.get("/chat/suggestions")
            suggestions = response.suggestions
        } catch {
            // Suggestions are optional, don't surface error
        }
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true
        error = nil

        // Add user message optimistically
        let userMessage = ChatMessage.localUserMessage(content: text)
        messages.append(userMessage)
        scrollToBottom()

        // Show typing indicator
        let typingMessage = ChatMessage.typingIndicator()
        messages.append(typingMessage)
        scrollToBottom()

        do {
            let body = ChatSendBody(message: text)
            let response: ChatResponse = try await APIClient.shared.post("/chat", body: body)

            // Remove typing indicator and add real response
            messages.removeAll { $0.id == "typing-indicator" }
            messages.append(response.toChatMessage())

            // Clear suggestions after first interaction
            if !suggestions.isEmpty {
                suggestions = []
            }
        } catch {
            // Remove typing indicator on error
            messages.removeAll { $0.id == "typing-indicator" }
            self.error = error.localizedDescription
        }

        isSending = false
        scrollToBottom()
    }

    func sendSuggestion(_ suggestion: ChatSuggestion) async {
        inputText = suggestion.text
        await sendMessage()
    }

    // MARK: - Scroll

    private func scrollToBottom() {
        scrollToBottomTrigger = UUID()
    }
}
