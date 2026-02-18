import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            disclaimerBanner
            messagesArea
            inputBar
        }
        .navigationTitle("Health Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.Colors.background)
        .task {
            await viewModel.loadInitialData()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private var disclaimerBanner: some View {
        Text("Wellness insights only — not medical advice.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, AppTheme.Spacing.xl)
            .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Pull to load more
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }

                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }

                    // Suggestions shown when no messages
                    if viewModel.showSuggestions {
                        suggestionsGrid
                    }

                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await viewModel.loadMoreHistory()
            }
            .onChange(of: viewModel.scrollToBottomTrigger) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                // Scroll to bottom on first load after messages arrive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.primaryFallback.opacity(0.5))
                .symbolRenderingMode(.hierarchical)

            Text("Health Assistant")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Ask me anything about your health data,\nbiomarkers, or nutrition recommendations.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.xxl)
    }

    // MARK: - Suggestions

    private var suggestionsGrid: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Suggestions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.xl)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
                    GridItem(.flexible(), spacing: AppTheme.Spacing.sm)
                ],
                spacing: AppTheme.Spacing.sm
            ) {
                ForEach(viewModel.suggestions) { suggestion in
                    suggestionChip(suggestion)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    private func suggestionChip(_ suggestion: ChatSuggestion) -> some View {
        Button {
            Task {
                await viewModel.sendSuggestion(suggestion)
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: suggestion.icon)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)

                Text(suggestion.text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer().frame(height: 100)
            ProgressView()
            Text("Loading conversation...")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Inline suggestions when there are messages
            if !viewModel.suggestions.isEmpty && !viewModel.messages.isEmpty {
                inlineSuggestions
            }

            Divider()

            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                TextField("Ask about your health...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                    )
                    .onSubmit {
                        guard viewModel.canSend else { return }
                        Task { await viewModel.sendMessage() }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.canSend
                            ? AppTheme.Colors.primaryFallback
                            : AppTheme.Colors.textSecondary.opacity(0.3)
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(!viewModel.canSend)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.background)
        }
    }

    // MARK: - Inline Suggestions

    private var inlineSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button {
                        Task { await viewModel.sendSuggestion(suggestion) }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: suggestion.icon)
                                .font(.caption)
                            Text(suggestion.text)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.primaryFallback.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
