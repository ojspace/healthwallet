import SwiftUI
import UniformTypeIdentifiers

struct UploadRecordView: View {
    @Environment(\.dismiss) private var dismiss
    var onUploadComplete: (() -> Void)?

    @State private var selectedFileURL: URL?
    @State private var selectedFileName: String?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var processingStatus: String?
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showVerification = false
    @State private var pendingRecord: HealthRecordResponse?
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    securityBadge
                    fileUploadArea
                    infoBanner
                }
                .padding(AppTheme.Spacing.xxl)
            }

            analyzeButton
        }
        .navigationTitle("Add New Health Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Upload Error", isPresented: $showError) {
            Button("Try Again") {
                Task { await uploadAndAnalyze() }
            }
            Button("Choose Different File") {
                selectedFileURL = nil
                selectedFileName = nil
                showFilePicker = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred during upload.")
        }
        .sheet(isPresented: $showVerification) {
            if let record = pendingRecord {
                RecordVerificationView(record: record) {
                    onUploadComplete?()
                    dismiss()
                }
            }
        }
    }

    private var securityBadge: some View {
        Label("Secure & Encrypted upload", systemImage: "lock.fill")
            .font(.caption.bold())
            .foregroundStyle(.green)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(.green.opacity(0.1))
            .clipShape(.capsule)
    }

    private var fileUploadArea: some View {
        Button {
            showFilePicker = true
        } label: {
            VStack(spacing: AppTheme.Spacing.md) {
                if isUploading {
                    uploadingView
                } else if let fileName = selectedFileName {
                    selectedFileView(fileName: fileName)
                } else {
                    defaultUploadView
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg)
                    .strokeBorder(
                        selectedFileName != nil ? .green.opacity(0.5) : AppTheme.Colors.primaryFallback.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: selectedFileName != nil ? [] : [8, 6])
                    )
                    .background(selectedFileName != nil ? .green.opacity(0.03) : AppTheme.Colors.primaryFallback.opacity(0.03))
            )
            .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }

    private var defaultUploadView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "cloud.arrow.up.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.Colors.primaryFallback)
                .padding(AppTheme.Spacing.lg)
                .background(.background)
                .clipShape(.circle)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

            Text("Select File from Files/Photos")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("Supporting PDFs from major labs (Quest, LabCorp). Max 10MB.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xxxl)
        }
    }

    private func selectedFileView(fileName: String) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "doc.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
                .padding(AppTheme.Spacing.lg)
                .background(.green.opacity(0.1))
                .clipShape(.circle)

            Text(fileName)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("Tap to change file")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var uploadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if let status = processingStatus {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                    .symbolEffect(.pulse)

                Text(status)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("This usually takes about 30 seconds...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, AppTheme.Spacing.xxxl)

                Text("Uploading... \(Int(uploadProgress * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
        }
    }

    private var infoBanner: some View {
        Label {
            Text("We extract biomarkers like Vitamin D, Cholesterol, and Hormones to give you personalized lifestyle recommendations.")
                .font(.caption)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        }
        .padding(AppTheme.Spacing.md)
        .background(.blue.opacity(0.06))
        .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
    }

    private var analyzeButton: some View {
        VStack {
            Button {
                Task {
                    await uploadAndAnalyze()
                }
            } label: {
                HStack {
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Analyze Record")
                            .bold()
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.lg)
                .foregroundStyle(.white)
                .background(canUpload ? AppTheme.Colors.primaryFallback : .gray)
                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
            }
            .disabled(!canUpload || isUploading)
        }
        .padding(AppTheme.Spacing.xxl)
        .background(.bar)
    }

    private var canUpload: Bool {
        selectedFileURL != nil
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file."
                showError = true
                return
            }

            selectedFileURL = url
            selectedFileName = url.lastPathComponent

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func uploadAndAnalyze() async {
        guard let fileURL = selectedFileURL else { return }

        isUploading = true
        uploadProgress = 0

        do {
            // Read file data
            let fileData = try Data(contentsOf: fileURL)

            // Stop accessing security-scoped resource
            fileURL.stopAccessingSecurityScopedResource()

            // Simulate upload progress
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                uploadProgress = Double(i) / 10.0
            }

            // Upload to backend
            let response = try await RecordsService.shared.uploadRecord(
                fileData: fileData,
                filename: selectedFileName ?? "document.pdf"
            )

            // Now poll for processing status
            processingStatus = "Analyzing your data..."

            let record = try await RecordsService.shared.pollRecordStatus(id: response.recordId)

            isUploading = false

            // Check if record needs verification (human-in-the-loop)
            if record.status == .pendingReview {
                pendingRecord = record
                showVerification = true
            } else {
                // Success - record is complete
                onUploadComplete?()
                dismiss()
            }

        } catch let apiError as APIError {
            isUploading = false
            processingStatus = nil
            errorMessage = apiError.localizedDescription
            showError = true
        } catch {
            isUploading = false
            processingStatus = nil
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        UploadRecordView()
    }
}
