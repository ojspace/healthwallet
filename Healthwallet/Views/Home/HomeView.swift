import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var selectedTab: Int
    @State private var calendarAlert: String?
    @State private var showCalendarSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                if viewModel.isLoading && viewModel.records.isEmpty {
                    loadingView
                } else {
                    // Daily Check-in (shows when not logged today)
                    if !viewModel.todayLogged {
                        DailyCheckInCard(homeViewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .scale.combined(with: .opacity)
                            ))
                    }

                    // Streak counter (tap to view Insights → Mood)
                    if let streak = viewModel.streak, streak.currentStreak > 0, viewModel.todayLogged {
                        Button { selectedTab = 1 } label: {
                            streakBanner(streak: streak)
                        }
                        .buttonStyle(.plain)
                    }

                    // HealthKit summary (always show if authorized)
                    if HealthKitManager.shared.isAuthorized {
                        healthKitCard
                    }

                    if viewModel.hasRecords {
                        // Dashboard header with wellness score and health age
                        DashboardHeaderView(
                            wellnessScore: viewModel.wellnessScore,
                            healthAge: viewModel.healthAge,
                            chronologicalAge: viewModel.chronologicalAge,
                            lastSync: viewModel.latestCheckInDate,
                            summary: viewModel.summary
                        )

                        // Biomarker quick summary
                        BiomarkerSummaryCard(
                            biomarkers: viewModel.latestBiomarkers,
                            checkInDate: viewModel.latestCheckInDate,
                            wellnessScore: viewModel.wellnessScore,
                            onBiomarkerTap: { viewModel.selectedBiomarker = $0 }
                        )

                        WeeklyFocusSection(
                            items: viewModel.weeklyFocusItems,
                            summary: viewModel.focusSummary,
                            onAction: { handleFocusAction($0) }
                        )

                        RecordHistorySection(records: viewModel.records)
                    } else {
                        // Habit-first empty state
                        emptyStateActions
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.sm)
            .animation(.easeInOut(duration: 0.3), value: viewModel.todayLogged)
        }
        .refreshable {
            await viewModel.refreshData()
            if HealthKitManager.shared.isAuthorized {
                await HealthKitManager.shared.fetchTodayStats()
            }
        }
        .navigationTitle("HealthWallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showUploadSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                }
                .accessibilityLabel("Upload health record")
            }
        }
        .sheet(item: $viewModel.selectedBiomarker) { biomarker in
            NavigationStack {
                BiomarkerDetailView(biomarker: biomarker)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.showUploadSheet) {
            NavigationStack {
                UploadRecordView(onUploadComplete: {
                    Task {
                        await viewModel.refreshData()
                    }
                })
            }
            .presentationDetents([.large])
        }
        .alert("Calendar", isPresented: .constant(calendarAlert != nil)) {
            Button("OK") { calendarAlert = nil }
        } message: {
            Text(calendarAlert ?? "")
        }
        .task {
            await viewModel.fetchRecords()
            if HealthKitManager.shared.isAuthorized {
                await HealthKitManager.shared.fetchTodayStats()
            }
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.error {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        Task { await viewModel.refreshData() }
                    } label: {
                        Text("Retry")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Colors.primaryFallback)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.error != nil)
    }

    // MARK: - Focus Action Handler

    private func handleFocusAction(_ item: WeeklyFocus) {
        switch item.actionType {
        case .reminder:
            Task {
                do {
                    try await CalendarManager.shared.addSupplementReminder(
                        name: item.reminderName ?? item.title,
                        timing: item.reminderTiming ?? "morning_with_food",
                        timingNote: item.subtitle,
                        hour: item.reminderHour ?? 8
                    )
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } catch {
                    calendarAlert = error.localizedDescription
                }
            }

        case .recipe:
            // Navigate to Chat tab with a recipe prompt
            selectedTab = 2

        case .activity:
            selectedTab = 2

        case .tip:
            // Tips are inline — no navigation needed
            break
        }
    }

    // MARK: - HealthKit Card

    private var healthKitCard: some View {
        let hk = HealthKitManager.shared
        let hasData = hk.todaySteps > 0 || hk.todaySleepHours > 0 || hk.todayRestingHR > 0

        return Group {
            if hasData {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Today's Vitals")
                            .font(.subheadline.bold())
                        Spacer()
                    }

                    HStack(spacing: AppTheme.Spacing.lg) {
                        if hk.todaySteps > 0 {
                            vitalPill(icon: "figure.walk", value: "\(hk.todaySteps)", label: "steps")
                        }
                        if hk.todaySleepHours > 0 {
                            vitalPill(icon: "bed.double.fill", value: String(format: "%.1f", hk.todaySleepHours), label: "hrs sleep")
                        }
                        if hk.todayRestingHR > 0 {
                            vitalPill(icon: "heart.fill", value: "\(Int(hk.todayRestingHR))", label: "RHR")
                        }
                        if hk.todayHRV > 0 {
                            vitalPill(icon: "waveform.path.ecg", value: "\(Int(hk.todayHRV))", label: "HRV")
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
        }
    }

    private func vitalPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.primaryFallback)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Streak Banner

    private func streakBanner(streak: StreakResponse) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text("\u{1F525}")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak.currentStreak)-day streak!")
                    .font(.subheadline.bold())
                Text("Best: \(streak.longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Empty State Actions

    private var emptyStateActions: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Chat prompt card
            Button {
                selectedTab = 2
            } label: {
                actionCard(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    iconColor: .purple,
                    title: "Talk to your AI health assistant",
                    subtitle: "Get personalized wellness insights"
                )
            }
            .buttonStyle(.plain)

            // Upload prompt card
            Button {
                viewModel.showUploadSheet = true
            } label: {
                actionCard(
                    icon: "arrow.up.doc.fill",
                    iconColor: AppTheme.Colors.primaryFallback,
                    title: "Upload your first lab report",
                    subtitle: "Turn blood work into actionable recommendations"
                )
            }
            .buttonStyle(.plain)

            // Insights prompt card
            Button {
                selectedTab = 1
            } label: {
                actionCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .orange,
                    title: "View your health insights",
                    subtitle: "Track biomarker trends and mood patterns"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.Spacing.lg)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading your health data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxxl * 2)
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(), selectedTab: .constant(0))
    }
}
