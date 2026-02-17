import SwiftUI

struct DashboardHeaderView: View {
    let wellnessScore: Int
    let healthAge: Int?
    let chronologicalAge: Int?
    let lastSync: String
    let summary: String?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Wellness Score Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(wellnessScore) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(wellnessScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text("Wellness")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Health Age Display
            if let healthAge = healthAge, let chronologicalAge = chronologicalAge {
                HStack(spacing: AppTheme.Spacing.xxl) {
                    AgeDisplay(
                        label: "Health Age",
                        value: healthAge,
                        isHighlighted: true
                    )

                    Divider()
                        .frame(height: 40)

                    AgeDisplay(
                        label: "Actual Age",
                        value: chronologicalAge,
                        isHighlighted: false
                    )
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

                // Age comparison message
                let ageDiff = chronologicalAge - healthAge
                if ageDiff > 0 {
                    Label("Your body is \(ageDiff) years younger!", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                } else if ageDiff < 0 {
                    Label("Room for improvement: \(abs(ageDiff)) years", systemImage: "arrow.up.heart")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            // Summary
            if let summary = summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private var scoreColor: Color {
        switch wellnessScore {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct AgeDisplay: View {
    let label: String
    let value: Int
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? AppTheme.Colors.primaryFallback : .primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardHeaderView(
        wellnessScore: 78,
        healthAge: 32,
        chronologicalAge: 38,
        lastSync: "Today, 2:30 PM",
        summary: "Your vitamin D levels have improved! Focus on maintaining your cholesterol."
    )
    .padding()
}
