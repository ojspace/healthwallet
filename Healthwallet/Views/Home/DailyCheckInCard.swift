import SwiftUI

struct DailyCheckInCard: View {
    @Bindable var homeViewModel: HomeViewModel
    @State private var quickLogVM = QuickLogViewModel()
    @State private var showFullLogSheet = false
    @State private var animatingMoodIndex: Int? = nil

    private let moods: [(emoji: String, label: String, value: Int)] = [
        ("😩", "Terrible", 1),
        ("😔", "Bad", 2),
        ("😐", "Okay", 3),
        ("🙂", "Good", 4),
        ("😀", "Great", 5)
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Header with streak
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Daily Check-in")
                        .font(.headline)

                    Text("How are you feeling today?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let streak = homeViewModel.streak, streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Text("\u{1F525}")
                            .font(.caption)
                        Text("\(streak.currentStreak)")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Colors.primaryFallback)
                    }
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.primaryFallback.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            // Mood buttons
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(moods, id: \.value) { mood in
                    moodButton(mood: mood)
                }
            }

            // Add details link
            Button {
                if quickLogVM.selectedMood == nil {
                    quickLogVM.selectedMood = 3
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
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .fill(Color(.systemBackground))
                .shadow(color: AppTheme.Colors.primaryFallback.opacity(0.12), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                .stroke(AppTheme.Colors.primaryFallback.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showFullLogSheet) {
            FullLogSheet(viewModel: quickLogVM, isPresented: $showFullLogSheet)
        }
        .onChange(of: quickLogVM.isLogged) { _, logged in
            if logged {
                homeViewModel.markTodayLogged()
            }
        }
    }

    private func moodButton(mood: (emoji: String, label: String, value: Int)) -> some View {
        let isSelected = quickLogVM.selectedMood == mood.value
        let isAnimating = animatingMoodIndex == mood.value

        return Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                animatingMoodIndex = mood.value
                quickLogVM.selectedMood = mood.value
            }

            quickLogVM.logMood(mood.value)
            homeViewModel.markTodayLogged()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    animatingMoodIndex = nil
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.system(size: 28))
                    .scaleEffect(isAnimating ? 1.3 : (isSelected ? 1.1 : 1.0))

                Text(mood.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? quickLogVM.moodColor(for: mood.value) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill(isSelected ? quickLogVM.moodColor(for: mood.value).opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DailyCheckInCard(homeViewModel: HomeViewModel())
        .padding()
        .background(Color(.systemGroupedBackground))
}
