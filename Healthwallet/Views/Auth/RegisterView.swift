import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthManager.self) private var authManager

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Header
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Text("Create Account")
                            .font(.title.bold())

                        Text("Start tracking your health journey")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    // Form
                    VStack(spacing: AppTheme.Spacing.lg) {
                        formField(title: "Full Name", placeholder: "John Doe", text: $fullName)
                            .textContentType(.name)

                        formField(title: "Email", placeholder: "you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Password")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("Min 8 characters", text: $password)
                                .textContentType(.newPassword)
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Confirm Password")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("••••••••", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                        .strokeBorder(passwordsMatch ? .clear : .red, lineWidth: 1)
                                )
                        }

                        if !passwordsMatch && !confirmPassword.isEmpty {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.xxl)

                    // Register Button
                    Button {
                        Task {
                            do {
                                try await authManager.register(
                                    email: email,
                                    password: password,
                                    fullName: fullName.isEmpty ? nil : fullName
                                )
                                dismiss()
                            } catch {
                                showError = true
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.lg)
                        .foregroundStyle(.white)
                        .background(isFormValid ? AppTheme.Colors.primaryFallback : .gray)
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal, AppTheme.Spacing.xxl)

                    // Apple Sign-In
                    VStack(spacing: AppTheme.Spacing.md) {
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("or")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }

                        Button {
                            Task {
                                do {
                                    try await AppleSignInManager.shared.signIn()
                                    dismiss()
                                } catch AppleSignInError.canceled {
                                    // User canceled, do nothing
                                } catch {
                                    showError = true
                                }
                            }
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "apple.logo")
                                    .font(.title3)
                                Text("Sign in with Apple")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.lg)
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .background(colorScheme == .dark ? .white : .black)
                            .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                        }
                        .disabled(AppleSignInManager.shared.isProcessing)
                    }
                    .padding(.horizontal, AppTheme.Spacing.xxl)

                    // Security Note
                    Label {
                        Text("Your data is encrypted and never shared with third parties.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(.green.opacity(0.06))
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Registration Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authManager.error ?? "Please try again.")
            }
        }
    }

    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surface)
                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
        }
    }

    private var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }
}

#Preview {
    RegisterView()
        .environment(AuthManager.shared)
}
