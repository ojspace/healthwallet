import SwiftUI

struct HealthKitOnboardingView: View {
    var onConnect: () -> Void
    var onSkip: () -> Void

    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateIcon = false
    @State private var animateRows = false

    private let healthKitManager = HealthKitManager.shared

    private let dataTypes: [(icon: String, title: String, description: String)] = [
        ("figure.walk", "Steps & Activity", "Track daily movement and active minutes"),
        ("bed.double.fill", "Sleep Analysis", "Monitor sleep duration and quality stages"),
        ("heart.fill", "Heart Rate & HRV", "Resting heart rate and heart rate variability"),
        ("scalemass.fill", "Weight", "Track body weight trends over time")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Heart Icon with Gradient
            heartIcon
                .padding(.bottom, AppTheme.Spacing.xxl)

            // Title and Subtitle
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Sync Apple Health")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text("Connect to auto-fill your profile and get daily readiness scores")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
            }
            .padding(.bottom, AppTheme.Spacing.xxxl)

            // Data Type List
            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(Array(dataTypes.enumerated()), id: \.element.icon) { index, dataType in
                    dataTypeRow(
                        icon: dataType.icon,
                        title: dataType.title,
                        description: dataType.description
                    )
                    .opacity(animateRows ? 1 : 0)
                    .offset(y: animateRows ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                        value: animateRows
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            Spacer()
            Spacer()

            // Buttons
            VStack(spacing: AppTheme.Spacing.lg) {
                // Connect Button
                Button {
                    connectHealthKit()
                } label: {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "heart.fill")
                        }
                        Text("Connect Apple Health")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.lg)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .disabled(isConnecting)

                // Skip Button
                Button {
                    onSkip()
                } label: {
                    Text("I'll do this later")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .disabled(isConnecting)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xxxl)
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateRows = true
            }

            // On simulator where HealthKit isn't available, auto-skip after brief delay
            if !healthKitManager.isAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onSkip()
                }
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("Try Again") {
                connectHealthKit()
            }
            Button("Skip") {
                onSkip()
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Heart Icon

    private var heartIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.15), Color.pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(animateIcon ? 1.1 : 0.95)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.2), Color.pink.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)

            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animateIcon ? 1.05 : 0.95)
        }
    }

    // MARK: - Data Type Row

    private func dataTypeRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle")
                .foregroundStyle(AppTheme.Colors.primaryFallback.opacity(0.5))
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    // MARK: - Connect Action

    private func connectHealthKit() {
        guard healthKitManager.isAvailable else {
            errorMessage = "Apple Health is not available on this device."
            showError = true
            return
        }

        isConnecting = true

        Task { @MainActor in
            do {
                try await healthKitManager.requestAuthorization()
                healthKitManager.markAuthorized()

                // Trigger an initial sync in the background
                Task {
                    await healthKitManager.fetchTodayStats()
                    await healthKitManager.syncToBackend()
                }

                onConnect()
            } catch {
                errorMessage = "Could not connect to Apple Health. Please try again or check your Settings."
                showError = true
            }

            isConnecting = false
        }
    }
}

// MARK: - Preview

#Preview {
    HealthKitOnboardingView(
        onConnect: { print("Connected") },
        onSkip: { print("Skipped") }
    )
}
