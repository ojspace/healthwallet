import SwiftUI

struct DoctorBriefExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var includeTrends = true
    @State private var includeCorrelations = true
    @State private var recordCount = 3
    @State private var isGenerating = false
    @State private var generatedPDF: Data?
    @State private var error: String?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title)
                                .foregroundStyle(AppTheme.Colors.primaryFallback)

                            VStack(alignment: .leading) {
                                Text("Doctor Brief")
                                    .font(.headline)
                                Text("Generate a professional summary for your healthcare provider")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Wellness insights only — not medical advice. Review with your healthcare provider.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                }

                Section("Include in Report") {
                    Toggle(isOn: $includeTrends) {
                        Label("Biomarker Trends", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Toggle(isOn: $includeCorrelations) {
                        Label("AI Correlations", systemImage: "link")
                    }
                }

                Section("Records to Include") {
                    Picker("Number of Records", selection: $recordCount) {
                        Text("Last 1").tag(1)
                        Text("Last 3").tag(3)
                        Text("Last 5").tag(5)
                        Text("All Available").tag(10)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating PDF...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if generatedPDF != nil {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            generateBrief()
                        } label: {
                            Label("Generate Report", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let error = error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Label("What's Included", systemImage: "info.circle")
                            .font(.subheadline.weight(.medium))

                        Group {
                            Text("- Patient summary with key biomarkers")
                            Text("- Flagged values requiring attention")
                            Text("- Historical trends (if selected)")
                            Text("- AI-detected correlations (if selected)")
                            Text("- Recommendations for discussion")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Export for Doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = generatedPDF {
                    ShareSheet(items: [pdfData])
                }
            }
        }
    }

    private func generateBrief() {
        isGenerating = true
        error = nil

        Task {
            do {
                generatedPDF = try await RecordsService.shared.exportDoctorBrief(
                    includeTrends: includeTrends,
                    includeCorrelations: includeCorrelations,
                    recordCount: recordCount
                )
            } catch {
                self.error = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DoctorBriefExportView()
}
