import SwiftUI
import RevenueCatUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountError = false
    @State private var deleteAccountErrorMessage: String?
    @State private var showDietaryPreferences = false
    @State private var showDoctorBriefExport = false
    @State private var showHealthGoals = false
    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    var body: some View {
        List {
            Section {
                HStack(spacing: AppTheme.Spacing.lg) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(AppTheme.Colors.primaryFallback)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.currentUser?.fullName ?? "User")
                            .font(.headline)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            Text(authManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if authManager.currentUser?.isPro ?? false {
                                Text("PRO")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primaryFallback, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                        }

                        if let diet = authManager.currentUser?.dietaryPreference {
                            HStack(spacing: 4) {
                                Image(systemName: diet.icon)
                                Text(diet.displayName)
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.primaryFallback)
                        }
                    }
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            }

            Section("Health Profile") {
                Button {
                    showDietaryPreferences = true
                } label: {
                    HStack {
                        Label("Dietary Preference", systemImage: "fork.knife")
                        Spacer()
                        if let diet = authManager.currentUser?.dietaryPreference {
                            Text(diet.displayName)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    showHealthGoals = true
                } label: {
                    HStack {
                        Label("Health Goals", systemImage: "target")
                        Spacer()
                        let goalsCount = authManager.currentUser?.healthGoals.count ?? 0
                        Text("\(goalsCount) selected")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                if let allergies = authManager.currentUser?.allergies, !allergies.isEmpty {
                    HStack {
                        Label("Allergies", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Text(allergies.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Upgrade to Pro (only shown for free users)
            if !(authManager.currentUser?.isPro ?? false) {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Unlock unlimited uploads & all features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section("Data") {
                NavigationLink {
                    ComparisonView()
                } label: {
                    Label("Biomarker Trends", systemImage: "chart.line.uptrend.xyaxis")
                }

                Button {
                    showDoctorBriefExport = true
                } label: {
                    HStack {
                        Label("Export for Doctor", systemImage: "doc.text.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section("Subscription") {
                if authManager.currentUser?.isPro ?? false {
                    Button {
                        showCustomerCenter = true
                    } label: {
                        HStack {
                            Label("Manage Subscription", systemImage: "creditcard.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Legal") {
                Link(destination: URL(string: "https://healthwallet.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }

                Link(destination: URL(string: "https://healthwallet.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }

            Section("About") {
                NavigationLink {
                    Text("Help & Support")
                } label: {
                    Label("Help & Support", systemImage: "questionmark.circle.fill")
                }

                HStack {
                    Label("Version", systemImage: "info.circle.fill")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Account", systemImage: "trash")
                        Spacer()
                    }
                }
            } footer: {
                Text("Permanently deletes your account and all health data from HealthWallet.")
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showDietaryPreferences) {
            DietaryPreferencesSheet()
        }
        .sheet(isPresented: $showDoctorBriefExport) {
            DoctorBriefExportView()
        }
        .sheet(isPresented: $showHealthGoals) {
            HealthGoalsSheet()
        }
        .sheet(isPresented: $showPaywall) {
            HealthWalletPaywallView()
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.logout()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        deleteAccountErrorMessage = error.localizedDescription
                        showDeleteAccountError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is permanent. Your account and all uploaded records will be deleted.")
        }
        .alert("Delete Account Failed", isPresented: $showDeleteAccountError) {
            Button("OK") {}
        } message: {
            Text(deleteAccountErrorMessage ?? "Something went wrong.")
        }
    }
}

// MARK: - Dietary Preferences Sheet

struct DietaryPreferencesSheet: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDiet: DietaryPreference = .omnivore
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(DietaryPreference.allCases, id: \.self) { diet in
                    Button {
                        selectedDiet = diet
                    } label: {
                        HStack {
                            Image(systemName: diet.icon)
                                .foregroundStyle(AppTheme.Colors.primaryFallback)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(diet.displayName)
                                    .foregroundStyle(.primary)
                                Text(diet.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedDiet == diet {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dietary Preference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePreference()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let current = authManager.currentUser?.dietaryPreference {
                    selectedDiet = current
                }
            }
            .alert("Save Failed", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Could not update dietary preference.")
            }
        }
    }

    private func savePreference() {
        isSaving = true
        Task {
            do {
                try await authManager.updateProfile(dietaryPreference: selectedDiet)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

// MARK: - Health Goals Sheet

struct HealthGoalsSheet: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoals: Set<String> = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage: String?

    private let availableGoals = [
        "Improve Energy",
        "Better Sleep",
        "Heart Health",
        "Weight Management",
        "Build Muscle",
        "Reduce Stress",
        "Immune Support",
        "Mental Clarity"
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableGoals, id: \.self) { goal in
                    Button {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    } label: {
                        HStack {
                            Text(goal)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedGoals.contains(goal) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.primaryFallback)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveGoals()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let goals = authManager.currentUser?.healthGoals {
                    selectedGoals = Set(goals)
                }
            }
            .alert("Save Failed", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Could not update health goals.")
            }
        }
    }

    private func saveGoals() {
        isSaving = true
        Task {
            do {
                try await authManager.updateProfile(healthGoals: Array(selectedGoals))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthManager.shared)
    }
}
