import SwiftUI
import Charts

struct ComparisonView: View {
    @State private var comparison: ComparisonResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedBiomarker: BiomarkerTrend?

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                if isLoading {
                    loadingView
                } else if let comparison = comparison {
                    // Summary header
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("\(comparison.recordsCompared) Records Compared")
                            .font(.headline)

                        if let start = comparison.dateRange["start"],
                           let end = comparison.dateRange["end"] {
                            Text("\(start) - \(end)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()

                    // Biomarker trends
                    ForEach(comparison.biomarkerTrends) { trend in
                        BiomarkerTrendCard(trend: trend)
                            .onTapGesture {
                                selectedBiomarker = trend
                            }
                    }
                } else if let error = error {
                    errorView(error)
                } else {
                    emptyView
                }
            }
            .padding()
        }
        // Title handled by InsightsView parent
        .task {
            await fetchComparison()
        }
        .refreshable {
            await fetchComparison()
        }
        .sheet(item: $selectedBiomarker) { trend in
            NavigationStack {
                BiomarkerTrendDetailView(trend: trend)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ProgressView()
            Text("Loading trends...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xxxl * 2)
    }

    private var emptyView: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Trends Yet")
                .font(.title2.bold())

            Text("Upload multiple records over time to see how your biomarkers are changing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Unable to Load Trends")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await fetchComparison() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func fetchComparison() async {
        isLoading = true
        error = nil

        do {
            comparison = try await RecordsService.shared.getComparison()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Biomarker Trend Card

struct BiomarkerTrendCard: View {
    let trend: BiomarkerTrend

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trend.name)
                        .font(.headline)

                    Text(trend.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .foregroundStyle(trendColor)

                    if let change = trend.changePercent {
                        Text(String(format: "%+.1f%%", change))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(trendColor)
                    }
                }
            }

            // Mini chart
            if !trend.dataPoints.isEmpty {
                Chart {
                    ForEach(Array(trend.dataPoints.enumerated()), id: \.offset) { index, point in
                        if let value = point["value"]?.value as? Double {
                            LineMark(
                                x: .value("Index", index),
                                y: .value("Value", value)
                            )
                            .foregroundStyle(trendColor)

                            PointMark(
                                x: .value("Index", index),
                                y: .value("Value", value)
                            )
                            .foregroundStyle(trendColor)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            }

            // Latest value
            if let lastPoint = trend.dataPoints.last,
               let value = lastPoint["value"]?.value as? Double {
                HStack {
                    Text("Latest:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f %@", value, trend.unit))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    private var trendIcon: String {
        switch trend.trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend.trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        default: return .orange
        }
    }
}

// MARK: - Trend Detail View

struct BiomarkerTrendDetailView: View {
    let trend: BiomarkerTrend
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                // Header
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(trend.name)
                        .font(.title.bold())

                    if let change = trend.changePercent {
                        HStack {
                            Image(systemName: trend.trend == "improving" ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            Text(String(format: "%+.1f%% change", change))
                        }
                        .font(.headline)
                        .foregroundStyle(trend.trend == "improving" ? .green : .red)
                    }
                }

                // Full chart
                if !trend.dataPoints.isEmpty {
                    Chart {
                        ForEach(Array(trend.dataPoints.enumerated()), id: \.offset) { index, point in
                            if let value = point["value"]?.value as? Double {
                                LineMark(
                                    x: .value("Index", index),
                                    y: .value("Value", value)
                                )
                                .foregroundStyle(AppTheme.Colors.primaryFallback)
                                .lineStyle(StrokeStyle(lineWidth: 2))

                                PointMark(
                                    x: .value("Index", index),
                                    y: .value("Value", value)
                                )
                                .foregroundStyle(AppTheme.Colors.primaryFallback)
                                .symbolSize(100)

                                AreaMark(
                                    x: .value("Index", index),
                                    y: .value("Value", value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primaryFallback.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                    }
                    .chartYAxisLabel(trend.unit)
                    .frame(height: 250)
                    .padding()
                }

                // Data points table
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    Text("History")
                        .font(.headline)

                    ForEach(Array(trend.dataPoints.enumerated()), id: \.offset) { index, point in
                        HStack {
                            if let date = point["date"]?.value as? String {
                                Text(date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Record \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let value = point["value"]?.value as? Double {
                                Text(String(format: "%.1f %@", value, trend.unit))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)

                        if index < trend.dataPoints.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .padding()
        }
        .navigationTitle("Trend Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ComparisonView()
    }
}
