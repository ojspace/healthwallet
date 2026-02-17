import SwiftUI

struct SupplementRecommendationCard: View {
    let recommendation: SupplementRecommendation
    let onAddToCalendar: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header: pill icon, name, dosage, priority badge
            HStack {
                Image(systemName: "pill.fill")
                    .foregroundStyle(priorityColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.name)
                        .font(.headline)

                    Text(recommendation.dosage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(recommendation.priority.capitalized)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.15))
                    .foregroundStyle(priorityColor)
                    .clipShape(Capsule())
            }

            // Reason linked to biomarker
            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Timing chip
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: recommendation.timingIcon)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .font(.caption)

                Text(recommendation.timingNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppTheme.Spacing.xs)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.primaryFallback.opacity(0.08))
            .clipShape(.rect(cornerRadius: AppTheme.Radius.xs))

            // Why this specific form
            if !recommendation.keywordReason.isEmpty {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(recommendation.keywordReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: AppTheme.Spacing.md) {
                // Shop on Amazon
                Button {
                    openAffiliateLink()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                        Text("Shop")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .foregroundStyle(.white)
                    .background(Color.orange)
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                }

                // Add to Calendar
                Button {
                    onAddToCalendar()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Remind")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .background(AppTheme.Colors.primaryFallback.opacity(0.12))
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(.rect(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private var priorityColor: Color {
        switch recommendation.priority {
        case "essential": return .red
        case "recommended": return .orange
        default: return .blue
        }
    }

    private func openAffiliateLink() {
        let keyword = recommendation.keyword
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try Amazon app deep link first, fall back to web URL
        if let amazonAppURL = URL(string: "com.amazon.mobile.shopping://www.amazon.com/s?k=\(keyword)"),
           UIApplication.shared.canOpenURL(amazonAppURL) {
            UIApplication.shared.open(amazonAppURL)
        } else if let webURL = URL(string: recommendation.amazonUrl) {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: - Preview

#Preview {
    SupplementRecommendationCard(
        recommendation: SupplementRecommendation(
            name: "Vitamin D3",
            dosage: "5000 IU",
            reason: "Your Vitamin D is low (24 ng/mL)",
            biomarkerLink: "Vitamin D",
            priority: "essential",
            keyword: "Vitamin D3 5000 IU K2 MK7",
            keywordReason: "D3 with K2 ensures proper calcium routing",
            timing: "morning_with_food",
            timingNote: "Take with breakfast (needs dietary fat)",
            amazonUrl: "https://www.amazon.com/s?k=Vitamin+D3+5000+IU+K2+MK7&tag=healthwallet-20",
            iherbUrl: nil
        ),
        onAddToCalendar: {}
    )
    .padding()
}
