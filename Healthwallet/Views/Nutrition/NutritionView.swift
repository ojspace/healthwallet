import SwiftUI

struct NutritionView: View {
    @State private var viewModel = NutritionViewModel()
    @State private var showUploadSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("Section", selection: $viewModel.selectedTab) {
                    ForEach(NutritionViewModel.NutritionTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, AppTheme.Spacing.lg)

                Text("Wellness recommendations only — not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.md)

                if viewModel.isLoading {
                    loadingState
                } else if !viewModel.hasData {
                    emptyState
                } else {
                    switch viewModel.selectedTab {
                    case .foods:
                        foodsSection
                    case .mealPlan:
                        mealPlanSection
                    }
                }
            }
            .padding(.bottom, AppTheme.Spacing.xxxl)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Nutrition")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ProgressView()
            Text("Loading your personalized plan...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "carrot.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No Recommendations Yet")
                .font(.headline)

            Text("Upload your blood work to get personalized nutrition recommendations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showUploadSheet = true
            } label: {
                Label("Upload Blood Work", systemImage: "arrow.up.doc.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.primaryFallback)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 80)
        .padding(.horizontal, AppTheme.Spacing.xxl)
        .sheet(isPresented: $showUploadSheet) {
            NavigationStack {
                UploadRecordView()
            }
        }
    }

    // MARK: - Foods Section

    private var foodsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Foods for You")
                    .font(.title3.bold())

                if let dateStr = viewModel.recordDateFormatted {
                    Text("Based on blood work from \(dateStr)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let pref = viewModel.dietaryPreference, !pref.isEmpty {
                    Label(pref.capitalized, systemImage: "leaf.fill")
                        .font(.caption)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .foregroundStyle(.green)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            // Nutrient Needs summary
            if !viewModel.needs.isEmpty {
                needsSummary
            }

            // Food cards
            LazyVStack(spacing: AppTheme.Spacing.md) {
                ForEach(viewModel.foods) { food in
                    FoodCard(food: food)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }

            // Total count note
            if let total = viewModel.recommendations?.total_unfiltered,
               total > viewModel.foods.count {
                Text("Showing top \(viewModel.foods.count) of \(total) recommended foods")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.Spacing.sm)
            }
        }
    }

    // MARK: - Nutrient Needs Summary

    private var needsSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Your Nutrient Needs")
                .font(.subheadline.bold())
                .padding(.horizontal, AppTheme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(viewModel.needs) { need in
                        NeedChip(need: need)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
            }
        }
    }

    // MARK: - Meal Plan Section

    private var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Weekly Meal Plan")
                    .font(.title3.bold())

                if let daysPlanned = viewModel.mealPlan?.days_planned {
                    Text("\(daysPlanned)-day plan based on your biomarkers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)

            // Day selector
            if !viewModel.mealPlanDays.isEmpty {
                daySelector
                dayMeals
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("Meal plan not available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.xxxl)
            }
        }
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.mealPlanDays) { dayPlan in
                    let isSelected = dayPlan.day == viewModel.selectedDay

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedDay = dayPlan.day
                        }
                    } label: {
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Text(dayPlan.shortDayName)
                                .font(.caption.bold())
                            Text("Day \(dayPlan.day)")
                                .font(.caption2)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                        .background(
                            isSelected
                                ? AppTheme.Colors.primaryFallback
                                : AppTheme.Colors.surface
                        )
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    // MARK: - Day Meals

    private var dayMeals: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if let dayPlan = viewModel.selectedDayPlan {
                ForEach(dayPlan.meals) { meal in
                    MealSection(meal: meal)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - Need Chip

private struct NeedChip: View {
    let need: NutrientNeed

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(need.nutrient)
                    .font(.caption.bold())
            }

            Text(need.reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(AppTheme.Spacing.sm)
        .frame(width: 160, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
    }

    private var statusColor: Color {
        switch need.status.lowercased() {
        case "low": return AppTheme.Colors.statusLow
        case "high": return AppTheme.Colors.statusHigh
        case "optimal": return AppTheme.Colors.statusOptimal
        default: return .gray
        }
    }
}

// MARK: - Meal Section

private struct MealSection: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Meal header
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: meal.mealIcon)
                    .font(.body)
                    .foregroundStyle(mealColor)
                    .frame(width: 28, height: 28)
                    .background(mealColor.opacity(0.12))
                    .clipShape(Circle())

                Text(meal.displayName)
                    .font(.subheadline.bold())

                Spacer()

                Text("\(meal.foods.count) items")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Food items
            VStack(spacing: 0) {
                ForEach(Array(meal.foods.enumerated()), id: \.element.id) { index, food in
                    CompactFoodCard(food: food)

                    if index < meal.foods.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(AppTheme.Colors.surface)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
        }
    }

    private var mealColor: Color {
        switch meal.type.lowercased() {
        case "breakfast": return .orange
        case "lunch": return .yellow
        case "dinner": return .indigo
        case "snack": return .mint
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NutritionView()
    }
}
