import SwiftUI

struct BiomarkerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BiomarkerDetailViewModel

    init(biomarker: Biomarker) {
        _viewModel = State(initialValue: BiomarkerDetailViewModel(biomarker: biomarker))
    }

    private var biomarker: Biomarker { viewModel.biomarker }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                GaugeView(
                    value: biomarker.value,
                    status: biomarker.status,
                    progress: viewModel.gaugeProgress
                )

                if !biomarker.description.isEmpty {
                    infoSection("What It Means") {
                        Text(biomarker.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !biomarker.whyItMatters.isEmpty {
                    infoSection("Why It Matters") {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(biomarker.whyItMatters, id: \.self) { reason in
                                Label(reason, systemImage: "circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .labelStyle(BulletLabelStyle())
                            }
                        }
                    }
                }

                if !biomarker.foodFixes.isEmpty {
                    foodFixesSection
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.vertical, AppTheme.Spacing.lg)
        }
        .navigationTitle(biomarker.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var foodFixesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Your Food Fixes")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(biomarker.foodFixes.enumerated()), id: \.element.id) { index, fix in
                    HStack(spacing: AppTheme.Spacing.lg) {
                        Image(systemName: fix.iconName)
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.primaryFallback)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.primaryFallback.opacity(0.1))
                            .clipShape(.circle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fix.name)
                                .font(.subheadline.bold())
                            Text(fix.portion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.md)

                    if index < biomarker.foodFixes.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .background(.background)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .padding(.top, 6)
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        BiomarkerDetailView(biomarker: SampleData.vitaminD)
    }
}
