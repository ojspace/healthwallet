import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            if !message.isUser && message.id == "typing-indicator" {
                typingIndicatorView
            } else {
                bubbleContent
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Bubble Content

    private var bubbleContent: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: AppTheme.Spacing.xs) {
            Text(markdownContent)
                .font(.body)
                .foregroundStyle(message.isUser ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .fill(message.isUser ? AppTheme.Colors.primaryFallback : AppTheme.Colors.surface)
                )
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .overlay(alignment: message.isUser ? .trailing : .leading) {
                    if showCopied {
                        Text("Copied")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                            .offset(y: -28)
                            .transition(.opacity)
                    }
                }

            if !message.formattedTime.isEmpty {
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, AppTheme.Spacing.xs)
            }
        }
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(
            markdown: message.content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.content)
    }

    // MARK: - Typing Indicator

    private var typingIndicatorView: some View {
        TypingDotsView()
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
    }
}

// MARK: - Typing Dots Animation

struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppTheme.Colors.textSecondary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    VStack(spacing: 0) {
        MessageBubble(message: ChatMessage(
            id: "1",
            role: "user",
            content: "What should I eat to improve my vitamin D?",
            created_at: "2026-02-08T10:30:00Z"
        ))
        MessageBubble(message: ChatMessage(
            id: "2",
            role: "assistant",
            content: "Great question! Here are some **vitamin D rich foods**:\n\n- Salmon and fatty fish\n- Egg yolks\n- Fortified milk\n\nAlso try getting 15 minutes of morning sun.",
            created_at: "2026-02-08T10:30:05Z"
        ))
        MessageBubble(message: .typingIndicator())
    }
    .padding(.vertical)
}
