import SwiftUI

// MARK: - Quick Log View Model

@Observable
@MainActor
final class QuickLogViewModel {
    var todayLog: QuickLogResponse?
    var logHistory: [QuickLogResponse] = []
    var streak: StreakResponse?

    var selectedMood: Int? = nil
    var energy: Double = 3
    var selectedSymptoms: Set<String> = []
    var notes: String = ""

    var isLogged = false
    var isSaving = false
    var isLoadingHistory = false
    var error: String?

    private static let allSymptoms = [
        "Headache", "Fatigue", "Brain Fog", "Joint Pain",
        "Bloating", "Insomnia", "Anxiety", "Skin Issues"
    ]

    var symptoms: [String] { Self.allSymptoms }

    // MARK: - Quick Mood Log

    func logMood(_ mood: Int) {
        selectedMood = mood
        isLogged = true

        Task {
            do {
                let log = QuickLog(
                    mood: mood,
                    energy: Int(energy),
                    symptoms: [],
                    notes: nil,
                    loggedAt: Date(),
                    date: nil
                )
                let _: QuickLogPostResponse = try await APIClient.shared.post(
                    "/logs/quick",
                    body: log
                )
            } catch {
                self.error = error.localizedDescription
            }
        }

        // Reset the logged indicator after a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            isLogged = false
        }
    }

    // MARK: - Full Log Save

    func saveFullLog() async {
        guard let mood = selectedMood else { return }

        isSaving = true
        error = nil

        do {
            let log = QuickLog(
                mood: mood,
                energy: Int(energy),
                symptoms: Array(selectedSymptoms),
                notes: notes.isEmpty ? nil : notes,
                loggedAt: Date(),
                date: nil
            )
            let _: QuickLogPostResponse = try await APIClient.shared.post(
                "/logs/quick",
                body: log
            )
            isLogged = true
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Fetch History

    func fetchHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            async let logsRequest: QuickLogListResponse = APIClient.shared.get("/logs")
            async let streakRequest: StreakResponse = APIClient.shared.get("/logs/streak")

            let (logsResponse, streakData) = try await (logsRequest, streakRequest)
            logHistory = logsResponse.logs
            streak = streakData
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    func moodColor(for mood: Int) -> Color {
        switch mood {
        case 5: return .green
        case 4: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case 3: return .yellow
        case 2: return .orange
        case 1: return .red
        default: return .gray
        }
    }

    func reset() {
        energy = 3
        selectedSymptoms = []
        notes = ""
    }
}

// MARK: - Quick Log Widget (Dashboard Inline)

struct QuickLogWidget: View {
    @State private var viewModel = QuickLogViewModel()
    @State private var showFullLogSheet = false
    @State private var animatingMoodIndex: Int? = nil

    private let moods: [(emoji: String, value: Int)] = [
        ("😩", 1), ("😔", 2), ("😐", 3), ("🙂", 4), ("😀", 5)
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Header
            HStack {
                Text("How are you feeling?")
                    .font(.headline)

                Spacer()

                if viewModel.isLogged {
                    loggedIndicator
                }
            }

            // Mood Row
            HStack(spacing: AppTheme.Spacing.md) {
                ForEach(moods, id: \.value) { mood in
                    moodButton(emoji: mood.emoji, value: mood.value)
                }
            }

            // Add details button
            Button {
                if viewModel.selectedMood == nil {
                    viewModel.selectedMood = 3
                }
                showFullLogSheet = true
            } label: {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "plus.circle")
                    Text("Add details")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.primaryFallback)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .sheet(isPresented: $showFullLogSheet) {
            FullLogSheet(viewModel: viewModel, isPresented: $showFullLogSheet)
        }
    }

    // MARK: - Mood Button

    private func moodButton(emoji: String, value: Int) -> some View {
        let isSelected = viewModel.selectedMood == value
        let isAnimating = animatingMoodIndex == value

        return Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                animatingMoodIndex = value
                viewModel.selectedMood = value
            }

            viewModel.logMood(value)

            // Clear bounce animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    animatingMoodIndex = nil
                }
            }
        } label: {
            Text(emoji)
                .font(.system(size: 32))
                .scaleEffect(isAnimating ? 1.3 : (isSelected ? 1.1 : 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .fill(isSelected ? viewModel.moodColor(for: value).opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .stroke(isSelected ? viewModel.moodColor(for: value) : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Logged Indicator

    private var loggedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("Logged!")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.isLogged)
    }
}

// MARK: - Full Log Sheet

struct FullLogSheet: View {
    @Bindable var viewModel: QuickLogViewModel
    @Binding var isPresented: Bool
    @FocusState private var isNotesFocused: Bool

    private let moods: [(emoji: String, value: Int)] = [
        ("😩", 1), ("😔", 2), ("😐", 3), ("🙂", 4), ("😀", 5)
    ]

    private let energyLabels = ["Exhausted", "Low", "Moderate", "Good", "Energized"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Mood Selection
                    moodSection

                    // Energy Slider
                    energySection

                    // Symptom Chips
                    symptomSection

                    // Notes Field
                    notesSection
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Log How You Feel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.reset()
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveFullLog()
                            if viewModel.error == nil {
                                isPresented = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.selectedMood == nil || viewModel.isSaving)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
            }
        }
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Mood")
                .font(.headline)

            HStack(spacing: AppTheme.Spacing.md) {
                ForEach(moods, id: \.value) { mood in
                    let isSelected = viewModel.selectedMood == mood.value

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            viewModel.selectedMood = mood.value
                        }
                    } label: {
                        Text(mood.emoji)
                            .font(.system(size: 36))
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                    .fill(isSelected ? viewModel.moodColor(for: mood.value).opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                    .stroke(isSelected ? viewModel.moodColor(for: mood.value) : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Energy Section

    private var energySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Energy")
                    .font(.headline)

                Spacer()

                Text(energyLabels[Int(viewModel.energy) - 1])
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
            }

            Slider(value: $viewModel.energy, in: 1...5, step: 1)
                .tint(AppTheme.Colors.primaryFallback)

            HStack {
                Text("Exhausted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Energized")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Symptom Section

    private var symptomSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Symptoms")
                .font(.headline)

            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.symptoms, id: \.self) { symptom in
                    SymptomChip(
                        label: symptom,
                        isSelected: viewModel.selectedSymptoms.contains(symptom),
                        onTap: {
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()

                            withAnimation(.easeInOut(duration: 0.2)) {
                                if viewModel.selectedSymptoms.contains(symptom) {
                                    viewModel.selectedSymptoms.remove(symptom)
                                } else {
                                    viewModel.selectedSymptoms.insert(symptom)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.notes.count)/500")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("How are you feeling today?", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .focused($isNotesFocused)
                .onChange(of: viewModel.notes) { _, newValue in
                    if newValue.count > 500 {
                        viewModel.notes = String(newValue.prefix(500))
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

// MARK: - Symptom Chip

struct SymptomChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.primaryFallback : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppTheme.Colors.primaryFallback : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// FlowLayout is defined in FoodCard.swift

// MARK: - Quick Log History View

struct QuickLogHistoryView: View {
    @State private var viewModel = QuickLogViewModel()
    @State private var selectedDate: String? = nil

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                if !viewModel.isLoadingHistory && viewModel.logHistory.isEmpty && viewModel.streak == nil {
                    // Empty state
                    VStack(spacing: AppTheme.Spacing.lg) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))

                        Text("No Mood Logs Yet")
                            .font(.headline)

                        Text("Log your mood from the Home screen to start tracking patterns over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                } else {
                    // Streak Counter
                    if let streak = viewModel.streak {
                        streakCard(streak: streak)
                    }

                    // Calendar Heat Map
                    calendarHeatMap

                    // Selected Day Detail
                    if let selectedDate = selectedDate,
                       let log = viewModel.logHistory.first(where: { $0.date == selectedDate }) {
                        dayDetailCard(log: log)
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Mood History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchHistory()
        }
        .overlay {
            if viewModel.isLoadingHistory {
                ProgressView()
            }
        }
    }

    // MARK: - Streak Card

    private func streakCard(streak: StreakResponse) -> some View {
        HStack(spacing: AppTheme.Spacing.xxl) {
            VStack(spacing: AppTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Text("\u{1F525}")
                        .font(.title2)

                    Text("\(streak.currentStreak)-day streak")
                        .font(.title3.weight(.bold))
                }

                Text("Keep it going!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(streak.longestStreak)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryFallback)

                Text("Best streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Calendar Heat Map

    private var calendarHeatMap: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Last 5 Weeks")
                .font(.headline)

            // Day labels
            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let days = generateCalendarDays(weeks: 5)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.dateString) { day in
                    calendarDayCell(day: day)
                }
            }

            // Legend
            HStack(spacing: AppTheme.Spacing.lg) {
                Spacer()
                legendItem(color: .gray.opacity(0.15), label: "No log")
                legendItem(color: .red.opacity(0.7), label: "Low")
                legendItem(color: .yellow.opacity(0.7), label: "Mid")
                legendItem(color: .green.opacity(0.7), label: "High")
                Spacer()
            }
            .padding(.top, AppTheme.Spacing.sm)
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private func calendarDayCell(day: CalendarDay) -> some View {
        let log = viewModel.logHistory.first(where: { $0.date == day.dateString })
        let isSelected = selectedDate == day.dateString
        let isToday = day.dateString == todayDateString()

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedDate == day.dateString {
                    selectedDate = nil
                } else {
                    selectedDate = day.dateString
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(moodCellColor(mood: log?.mood))
                    .aspectRatio(1, contentMode: .fit)

                if isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.Colors.primaryFallback, lineWidth: 2)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white, lineWidth: 2)
                }

                Text("\(day.dayNumber)")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(log != nil ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func moodCellColor(mood: Int?) -> Color {
        guard let mood = mood else { return Color.gray.opacity(0.15) }
        switch mood {
        case 5: return .green.opacity(0.85)
        case 4: return .green.opacity(0.55)
        case 3: return .yellow.opacity(0.7)
        case 2: return .orange.opacity(0.7)
        case 1: return .red.opacity(0.7)
        default: return Color.gray.opacity(0.15)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Day Detail Card

    private func dayDetailCard(log: QuickLogResponse) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Text(formattedDate(log.date))
                    .font(.headline)

                Spacer()

                Text(moodEmoji(for: log.mood))
                    .font(.title2)
            }

            Divider()

            HStack(spacing: AppTheme.Spacing.xxl) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Mood")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(moodLabel(for: log.mood))
                        .font(.subheadline.weight(.medium))
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Energy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(energyLabel(for: log.energy))
                        .font(.subheadline.weight(.medium))
                }
            }

            if !log.symptoms.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Symptoms")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: AppTheme.Spacing.xs) {
                        ForEach(log.symptoms, id: \.self) { symptom in
                            Text(symptom)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(Capsule().fill(AppTheme.Colors.primaryFallback.opacity(0.8)))
                        }
                    }
                }
            }

            if let notes = log.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
    }

    // MARK: - Helpers

    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "\u{1F629}"
        case 2: return "\u{1F614}"
        case 3: return "\u{1F610}"
        case 4: return "\u{1F642}"
        case 5: return "\u{1F600}"
        default: return "\u{1F610}"
        }
    }

    private func moodLabel(for mood: Int) -> String {
        switch mood {
        case 1: return "Terrible"
        case 2: return "Bad"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Unknown"
        }
    }

    private func energyLabel(for energy: Int) -> String {
        switch energy {
        case 1: return "Exhausted"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "Good"
        case 5: return "Energized"
        default: return "Unknown"
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private func formattedDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium

        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        return outputFormatter.string(from: date)
    }

    private func generateCalendarDays(weeks: Int) -> [CalendarDay] {
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: startOfToday) // 1 = Sunday
        let daysFromSunday = weekday - 1

        // Go back to the start of the current week, then back (weeks-1) more weeks
        guard let startOfCurrentWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfToday),
              let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: startOfCurrentWeek) else {
            return []
        }

        let totalDays = weeks * 7
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var days: [CalendarDay] = []
        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: gridStart) else { continue }

            // Do not include future dates beyond today
            if date > startOfToday {
                days.append(CalendarDay(
                    dateString: formatter.string(from: date),
                    dayNumber: calendar.component(.day, from: date),
                    isFuture: true
                ))
            } else {
                days.append(CalendarDay(
                    dateString: formatter.string(from: date),
                    dayNumber: calendar.component(.day, from: date),
                    isFuture: false
                ))
            }
        }

        return days
    }
}

// MARK: - Calendar Day Model

private struct CalendarDay: Hashable {
    let dateString: String
    let dayNumber: Int
    let isFuture: Bool
}

// MARK: - Previews

#Preview("Widget") {
    VStack {
        QuickLogWidget()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("History") {
    NavigationStack {
        QuickLogHistoryView()
    }
}
