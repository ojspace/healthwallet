import SwiftUI

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = OnboardingViewModel()
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ZStack {
            // Main chat-style onboarding
            chatOnboarding
                .opacity(viewModel.currentStep == .healthKit ? 0 : 1)

            // Full-screen HealthKit overlay when on that step
            if viewModel.currentStep == .healthKit {
                HealthKitOnboardingView(
                    onConnect: {
                        viewModel.onHealthKitConnected()
                    },
                    onSkip: {
                        viewModel.onHealthKitSkipped()
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: viewModel.currentStep == .healthKit)
        .background(AppTheme.Colors.background)
        .onAppear {
            viewModel.start()
        }
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Chat Onboarding

    private var chatOnboarding: some View {
        VStack(spacing: 0) {
            // MARK: - Progress Bar
            progressBar
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)

            // MARK: - Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        }

                        // Typing indicator
                        if viewModel.isTyping {
                            TypingIndicatorView()
                                .id("typing")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Input area (inline in the chat)
                        if viewModel.isShowingInput && !viewModel.isTyping && viewModel.currentStep != .healthKit {
                            inputForCurrentStep
                                .id("input-\(viewModel.currentStep.rawValue)")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(.top, AppTheme.Spacing.sm)
                        }

                        // Invisible spacer for scroll anchoring
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    withAnimation(.spring(duration: 0.35)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isShowingInput) {
                    withAnimation(.spring(duration: 0.35)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isTyping) {
                    withAnimation(.spring(duration: 0.35)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // MARK: - Bottom Action Bar
            Text("Wellness insights only — not medical advice.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.xs)
            bottomBar
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                Capsule()
                    .fill(AppTheme.Colors.primaryFallback)
                    .frame(width: geo.size.width * viewModel.currentStep.progress, height: 4)
                    .animation(.spring(duration: 0.4), value: viewModel.currentStep)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Input Router

    @ViewBuilder
    private var inputForCurrentStep: some View {
        switch viewModel.currentStep {
        case .welcome:
            welcomeInput
        case .healthKit:
            EmptyView() // Handled as full-screen overlay
        case .name:
            nameInput
        case .dateOfBirth:
            dateOfBirthInput
        case .biologicalSex:
            biologicalSexInput
        case .healthGoals:
            healthGoalsInput
        case .dietaryPreference:
            dietaryPreferenceInput
        case .allergies:
            allergiesInput
        case .healthConditions:
            healthConditionsInput
        case .summary:
            summaryInput
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeInput: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.Colors.primaryFallback, AppTheme.Colors.primaryFallback.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, AppTheme.Spacing.lg)

            Text("HealthWallet")
                .font(.title.bold())

            Text("Your personal health translator")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }

    // MARK: - Step: Name

    private var nameInput: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Your name", text: $viewModel.name)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
                .focused($isNameFieldFocused)
                .submitLabel(.next)
                .onSubmit {
                    if viewModel.canProceed {
                        viewModel.advanceStep()
                    }
                }
                .onAppear {
                    isNameFieldFocused = true
                }

            if !viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    isNameFieldFocused = false
                    viewModel.advanceStep()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                }
            }
        }
    }

    // MARK: - Step: Date of Birth

    private var dateOfBirthInput: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.showDatePicker.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppTheme.Colors.primaryFallback)

                    Text(viewModel.dateOfBirth.formatted(.dateTime.month(.wide).day().year()))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("Age: \(viewModel.age)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryFallback)

                    Image(systemName: viewModel.showDatePicker ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(AppTheme.Spacing.lg)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .buttonStyle(.plain)

            if viewModel.showDatePicker {
                DatePicker(
                    "Date of Birth",
                    selection: $viewModel.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Step: Biological Sex

    private var biologicalSexInput: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ForEach(BiologicalSex.allCases, id: \.self) { sex in
                let isSelected = viewModel.biologicalSex == sex
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        viewModel.biologicalSex = sex
                    }
                } label: {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: sex.icon)
                            .font(.title2)
                            .foregroundStyle(isSelected ? .white : AppTheme.Colors.primaryFallback)

                        Text(sex.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.lg)
                    .background(isSelected ? AppTheme.Colors.primaryFallback : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                            .stroke(isSelected ? AppTheme.Colors.primaryFallback : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Step: Health Goals

    private var healthGoalsInput: some View {
        FlowLayout(spacing: AppTheme.Spacing.sm) {
            ForEach(viewModel.availableGoals, id: \.self) { goal in
                let isSelected = viewModel.healthGoals.contains(goal)
                ChipView(
                    label: goal,
                    icon: viewModel.iconForGoal(goal),
                    isSelected: isSelected
                ) {
                    withAnimation(.spring(duration: 0.25)) {
                        viewModel.toggleGoal(goal)
                    }
                }
            }
        }
    }

    // MARK: - Step: Dietary Preference

    private var dietaryPreferenceInput: some View {
        FlowLayout(spacing: AppTheme.Spacing.sm) {
            ForEach(DietaryPreference.allCases, id: \.self) { diet in
                let isSelected = viewModel.dietaryPreference == diet
                ChipView(
                    label: diet.displayName,
                    icon: diet.icon,
                    isSelected: isSelected
                ) {
                    withAnimation(.spring(duration: 0.25)) {
                        viewModel.dietaryPreference = diet
                    }
                }
            }
        }
    }

    // MARK: - Step: Allergies

    private var allergiesInput: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.availableAllergies, id: \.self) { allergy in
                    let isSelected = viewModel.allergies.contains(allergy)
                    ChipView(
                        label: allergy,
                        icon: viewModel.iconForAllergy(allergy),
                        isSelected: isSelected
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.toggleAllergy(allergy)
                        }
                    }
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Other allergy...", text: $viewModel.customAllergy)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }

    // MARK: - Step: Health Conditions

    private var healthConditionsInput: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.availableConditions, id: \.self) { condition in
                    let isSelected = viewModel.healthConditions.contains(condition)
                    ChipView(
                        label: condition,
                        icon: viewModel.iconForCondition(condition),
                        isSelected: isSelected
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            viewModel.toggleCondition(condition)
                        }
                    }
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Other condition...", text: $viewModel.customCondition)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }

    // MARK: - Step: Summary

    private var summaryInput: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if viewModel.healthKitConnected {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Apple Health Connected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            if !viewModel.name.isEmpty {
                SummaryRow(label: "Name", value: viewModel.name)
            }
            SummaryRow(label: "Age", value: "\(viewModel.age) years old")
            SummaryRow(label: "Biological Sex", value: viewModel.biologicalSex?.displayName ?? "Not specified")
            SummaryRow(label: "Goals", value: viewModel.healthGoals.isEmpty ? "None selected" : viewModel.healthGoals.sorted().joined(separator: ", "))
            SummaryRow(label: "Diet", value: viewModel.dietaryPreference?.displayName ?? "Not specified")
            SummaryRow(label: "Allergies", value: viewModel.combinedAllergies.isEmpty ? "None" : viewModel.combinedAllergies.joined(separator: ", "))
            SummaryRow(label: "Conditions", value: viewModel.combinedConditions.isEmpty ? "None" : viewModel.combinedConditions.joined(separator: ", "))
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Bottom Action Bar

    private var bottomBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Back button
            if viewModel.currentStep.rawValue > 0 && viewModel.currentStep != .healthKit {
                Button {
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }

            Spacer()

            // Next / Let's Go button (hidden during HealthKit step)
            if viewModel.currentStep != .healthKit {
                Button {
                    if viewModel.currentStep == .summary {
                        Task {
                            await viewModel.submitOnboarding(authManager: authManager)
                        }
                    } else {
                        viewModel.advanceStep()
                    }
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonTitle)
                            .fontWeight(.semibold)
                        if !viewModel.isSubmitting && viewModel.currentStep != .summary {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(
                        viewModel.canProceed
                        ? AppTheme.Colors.primaryFallback
                        : AppTheme.Colors.primaryFallback.opacity(0.4)
                    )
                    .clipShape(Capsule())
                }
                .disabled(!viewModel.canProceed || viewModel.isSubmitting || viewModel.isTyping)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var buttonTitle: String {
        switch viewModel.currentStep {
        case .welcome:
            return "Get Started"
        case .summary:
            return "Let's Go!"
        default:
            return "Next"
        }
    }
}

// MARK: - Chat Bubble View

private struct ChatBubbleView: View {
    let message: OnboardingBubble

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            if message.isBot {
                // Bot avatar
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .frame(width: 32, height: 32)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(ChatBubbleShape(isBot: true))

                Spacer(minLength: 48)
            } else {
                Spacer(minLength: 48)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primaryFallback)
                    .clipShape(ChatBubbleShape(isBot: false))
            }
        }
    }
}

// MARK: - Chat Bubble Shape

private struct ChatBubbleShape: Shape {
    let isBot: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let smallRadius: CGFloat = 4

        var path = Path()

        if isBot {
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: smallRadius,
                    bottomLeading: radius,
                    bottomTrailing: radius,
                    topTrailing: radius
                )
            )
        } else {
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: smallRadius,
                    topTrailing: radius
                )
            )
        }

        return path
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.primaryFallback)
                .frame(width: 32, height: 32)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: animating ? -4 : 4)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.lg)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(ChatBubbleShape(isBot: true))

            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Chip View

private struct ChipView: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.primaryFallback)

                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(isSelected ? AppTheme.Colors.primaryFallback : Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// FlowLayout is defined in FoodCard.swift

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AuthManager.shared)
}
