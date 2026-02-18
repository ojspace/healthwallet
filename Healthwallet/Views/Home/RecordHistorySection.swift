import SwiftUI

struct RecordHistorySection: View {
    let records: [HealthRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Text("Record History")
                    .font(.title3.bold())
                Spacer()
                // View All removed — records already visible below
            }

            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    RecordRow(record: record)

                    if index < records.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(.background)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

private struct RecordRow: View {
    let record: HealthRecord

    private var iconColor: Color {
        switch record.type {
        case .bloodPanel: .red
        case .annualPhysical: .blue
        case .hormonePanel: .purple
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: record.type.iconName)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.subheadline.bold())

                Text("\(record.formattedDate) \u{2022} \(record.provider)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.quaternary)
        }
        .padding(AppTheme.Spacing.lg)
        .contentShape(.rect)
    }
}

#Preview {
    RecordHistorySection(records: SampleData.records)
        .padding()
}
