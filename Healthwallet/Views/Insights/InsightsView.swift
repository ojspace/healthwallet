import SwiftUI

struct InsightsView: View {
    @State private var selectedSection: InsightSection = .trends

    enum InsightSection: String, CaseIterable {
        case trends = "Biomarkers"
        case mood = "Mood"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(InsightSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)

            switch selectedSection {
            case .trends:
                ComparisonView()
            case .mood:
                QuickLogHistoryView()
            }
        }
        .navigationTitle("Insights")
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
}
