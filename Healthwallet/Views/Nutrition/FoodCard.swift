import SwiftUI

struct FoodCard: View {
    let food: FoodRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header: Name + Category
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Label(food.category.capitalized, systemImage: food.categoryIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: food.categoryIcon)
                    .font(.title3)
                    .foregroundStyle(categoryColor.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Circle())
            }

            // Nutrients as pills
            if !food.nutrients.isEmpty {
                nutrientPills
            }

            // Serving size
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "scalemass.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(food.serving)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Why explanation
            if !food.why.isEmpty {
                Text(food.why)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
            }

            // Tags
            if !food.tags.isEmpty {
                tagRow
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(.rect(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Nutrient Pills

    private var nutrientPills: some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(food.nutrients, id: \.self) { nutrient in
                Text(nutrient)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .background(AppTheme.Colors.primaryFallback.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Tags

    private var tagRow: some View {
        FlowLayout(spacing: AppTheme.Spacing.xs) {
            ForEach(food.tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 2)
                    .foregroundStyle(.secondary)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch food.category.lowercased() {
        case "protein": return .blue
        case "vegetable": return .green
        case "fruit": return .orange
        case "grain": return .brown
        case "fat": return .yellow
        case "legume": return .mint
        case "dairy": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Flow Layout for wrapping pills/tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Compact Food Card (for meal plan)

struct CompactFoodCard: View {
    let food: FoodRecommendation

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: food.categoryIcon)
                .font(.body)
                .foregroundStyle(categoryColor)
                .frame(width: 32, height: 32)
                .background(categoryColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: AppTheme.Radius.xs))

            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.subheadline.weight(.medium))

                Text(food.serving)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !food.nutrients.isEmpty {
                Text(food.nutrients.prefix(2).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var categoryColor: Color {
        switch food.category.lowercased() {
        case "protein": return .blue
        case "vegetable": return .green
        case "fruit": return .orange
        case "grain": return .brown
        case "fat": return .yellow
        case "legume": return .mint
        case "dairy": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            FoodCard(food: FoodRecommendation(
                name: "Wild Salmon",
                category: "protein",
                nutrients: ["Vitamin D", "Omega-3", "B12"],
                why: "Rich in Vitamin D and Omega-3 fatty acids to support your low Vitamin D levels",
                serving: "4 oz fillet, 2-3x per week",
                tags: ["anti-inflammatory", "heart-healthy"]
            ))

            FoodCard(food: FoodRecommendation(
                name: "Spinach",
                category: "vegetable",
                nutrients: ["Iron", "Folate", "Vitamin K"],
                why: "Excellent source of iron to help raise your low iron levels",
                serving: "2 cups raw or 1 cup cooked",
                tags: ["vegetarian", "low-calorie"]
            ))
        }
        .padding()
    }
}
