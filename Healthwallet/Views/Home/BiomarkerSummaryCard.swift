import SwiftUI

struct BiomarkerSummaryCard: View {
    let biomarkers: [Biomarker]
    let checkInDate: String
    var wellnessScore: Int = 0
    var onBiomarkerTap: (Biomarker) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Header with score
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest Check-in")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(checkInDate)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                if wellnessScore > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Wellness Score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 4) {
                            Text("\(wellnessScore)")
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Text("/100")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }

            // Biomarkers
            HStack(spacing: 0) {
                ForEach(Array(biomarkers.prefix(3).enumerated()), id: \.element.id) { index, biomarker in
                    if index > 0 {
                        Divider()
                            .frame(height: 60)
                            .background(.white.opacity(0.15))
                            .padding(.horizontal, AppTheme.Spacing.sm)
                    }

                    BiomarkerColumn(biomarker: biomarker)
                        .onTapGesture { onBiomarkerTap(biomarker) }
                }
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.24, green: 0.43, blue: 0.53))
        .clipShape(.rect(cornerRadius: AppTheme.Radius.xl))
    }
}

private struct BiomarkerColumn: View {
    let biomarker: Biomarker

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(biomarker.name)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(biomarker.value, format: .number.precision(.fractionLength(0)))
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(biomarker.unit)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            StatusBadge(status: biomarker.status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let statusText: String
    let statusColor: Color

    init(status: BiomarkerStatus) {
        self.statusText = status.rawValue.capitalized
        self.statusColor = status.color
    }

    init(status: String) {
        self.statusText = status.capitalized
        switch status.lowercased() {
        case "optimal", "normal": self.statusColor = .green
        case "low": self.statusColor = .yellow
        case "high": self.statusColor = .red
        default: self.statusColor = .gray
        }
    }

    var body: some View {
        Text(statusText)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.2))
            .clipShape(.capsule)
            .foregroundStyle(statusColor)
    }
}

#Preview {
    BiomarkerSummaryCard(
        biomarkers: SampleData.biomarkers,
        checkInDate: "Oct 26, 2023",
        wellnessScore: 84
    )
    .padding()
}
