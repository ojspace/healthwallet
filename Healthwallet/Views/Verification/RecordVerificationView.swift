import SwiftUI

struct RecordVerificationView: View {
    let record: HealthRecordResponse
    let onVerified: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var biomarkerEdits: [String: BiomarkerEdit] = [:]
    @State private var isSubmitting = false
    @State private var error: String?

    private var parsedBiomarkers: [BiomarkerResponse] {
        record.biomarkers.compactMap { dict -> BiomarkerResponse? in
            guard let name = dict["name"]?.value as? String,
                  let value = dict["value"]?.value as? Double,
                  let unit = dict["unit"]?.value as? String else { return nil }
            let status = dict["status"]?.value as? String
            let refRange = dict["reference_range"]?.value as? [String: Any]
            let refStr: String? = if let min = refRange?["min"], let max = refRange?["max"] {
                "\(min)-\(max)"
            } else {
                nil
            }
            let confidence = dict["confidence"]?.value as? Double
            return BiomarkerResponse(name: name, value: value, unit: unit, status: status ?? "optimal", referenceRange: refStr, confidence: confidence)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Header
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.Colors.primaryFallback)

                        Text("Verify Your Results")
                            .font(.title2.bold())

                        Text("Our AI extracted these biomarkers from your report. Please review and correct any errors before saving.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Biomarkers list
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        ForEach(parsedBiomarkers, id: \.name) { biomarker in
                            BiomarkerVerificationCard(
                                biomarker: biomarker,
                                edit: biomarkerEdits[biomarker.name],
                                onEdit: { edit in
                                    biomarkerEdits[biomarker.name] = edit
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Error display
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
            }
            .navigationTitle("Review Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Approve") {
                        submitVerification(approved: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Button {
                        submitVerification(approved: true)
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Approve & Save")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSubmitting)

                    if !biomarkerEdits.isEmpty {
                        Text("\(biomarkerEdits.count) change(s) pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private func submitVerification(approved: Bool) {
        isSubmitting = true
        error = nil

        Task {
            do {
                try await RecordsService.shared.verifyRecord(
                    id: record.id,
                    edits: Array(biomarkerEdits.values),
                    approved: approved
                )
                onVerified()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Biomarker Verification Card

struct BiomarkerVerificationCard: View {
    let biomarker: BiomarkerResponse
    let edit: BiomarkerEdit?
    let onEdit: (BiomarkerEdit?) -> Void

    @State private var isEditing = false
    @State private var editedValue: String = ""
    @State private var editedUnit: String = ""

    var displayValue: Double {
        edit?.newValue ?? biomarker.value
    }

    var displayUnit: String {
        edit?.newUnit ?? biomarker.unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(biomarker.name)
                        .font(.headline)

                    HStack(spacing: 4) {
                        StatusBadge(status: biomarker.status)

                        if edit != nil {
                            Text("(edited)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                Button {
                    editedValue = String(format: "%.2f", displayValue)
                    editedUnit = displayUnit
                    isEditing = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                }
            }

            HStack {
                Text(String(format: "%.2f", displayValue))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(displayUnit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let refRange = biomarker.referenceRange {
                    Text("Ref: \(refRange)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Confidence indicator
            if let confidence = biomarker.confidence {
                HStack {
                    Text("AI Confidence:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView(value: confidence)
                        .tint(confidenceColor(confidence))
                        .frame(width: 100)

                    Text("\(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .sheet(isPresented: $isEditing) {
            EditBiomarkerSheet(
                biomarkerName: biomarker.name,
                value: $editedValue,
                unit: $editedUnit,
                onSave: {
                    if let newValue = Double(editedValue) {
                        onEdit(BiomarkerEdit(
                            name: biomarker.name,
                            newValue: newValue,
                            newUnit: editedUnit.isEmpty ? nil : editedUnit
                        ))
                    }
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                },
                onReset: {
                    onEdit(nil)
                    isEditing = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Edit Biomarker Sheet

struct EditBiomarkerSheet: View {
    let biomarkerName: String
    @Binding var value: String
    @Binding var unit: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Biomarker") {
                    Text(biomarkerName)
                        .font(.headline)
                }

                Section("Value") {
                    TextField("Value", text: $value)
                        .keyboardType(.decimalPad)
                }

                Section("Unit") {
                    TextField("Unit (e.g., mg/dL)", text: $unit)
                }

                Section {
                    Button("Reset to Original", role: .destructive) {
                        onReset()
                    }
                }
            }
            .navigationTitle("Edit Value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave() }
                        .disabled(value.isEmpty)
                }
            }
        }
    }
}

#Preview {
    RecordVerificationView(
        record: HealthRecordResponse(
            id: "1",
            status: .pendingReview,
            originalFilename: "blood_work.pdf",
            recordDate: nil,
            labProvider: nil,
            recordType: nil,
            biomarkers: [
                ["name": AnyCodable("Vitamin D"), "value": AnyCodable(22.5), "unit": AnyCodable("ng/mL"), "status": AnyCodable("low")]
            ],
            summary: nil,
            correlations: nil,
            keyFindings: nil,
            recommendations: [],
            foodRecommendations: nil,
            supplementProtocol: nil,
            wellnessScore: nil,
            healthAge: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        onVerified: {}
    )
}
