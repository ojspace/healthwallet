import SwiftUI

struct WeeklyFocusSection: View {
    let items: [WeeklyFocus]
    let summary: String
    var onAction: ((WeeklyFocus) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Your Weekly Focus")
                .font(.title3.bold())

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                LazyHStack(spacing: AppTheme.Spacing.lg) {
                    ForEach(items) { item in
                        WeeklyFocusCard(item: item, onAction: onAction)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }
}

private struct WeeklyFocusCard: View {
    let item: WeeklyFocus
    var onAction: ((WeeklyFocus) -> Void)?
    @State private var didTap = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.md) {
                cardIcon
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.bold())

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Button {
                didTap = true
                onAction?(item)
                // Reset after a delay for visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    didTap = false
                }
            } label: {
                HStack(spacing: 4) {
                    if didTap && item.actionType == .reminder {
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                        Text("Added!")
                    } else {
                        if item.actionType == .reminder {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                        }
                        Text(item.actionLabel)
                    }
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(buttonBackground)
                .foregroundStyle(buttonForeground)
                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: 240)
        .background(.background)
        .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var buttonBackground: Color {
        if didTap && item.actionType == .reminder {
            return Color.green.opacity(0.15)
        }
        return AppTheme.Colors.primaryFallback.opacity(0.1)
    }

    private var buttonForeground: Color {
        if didTap && item.actionType == .reminder {
            return .green
        }
        return AppTheme.Colors.primaryFallback
    }

    @ViewBuilder
    private var cardIcon: some View {
        if let url = item.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.orange.opacity(0.15)
            }
        } else {
            ZStack {
                iconBackgroundColor.opacity(0.15)
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundStyle(iconBackgroundColor)
            }
        }
    }

    private var iconBackgroundColor: Color {
        switch item.actionType {
        case .reminder: return .orange
        case .recipe: return .green
        case .activity: return .blue
        case .tip: return .yellow
        }
    }
}

#Preview {
    WeeklyFocusSection(
        items: SampleData.weeklyFocusItems,
        summary: "Based on your low Vitamin D and high LDL."
    )
    .padding()
}
