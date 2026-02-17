import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Logo & Header
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.Colors.primaryFallback)

                        Text("HealthWallet")
                            .font(.largeTitle.bold())

                        Text("Turn your lab results into actionable fuel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppTheme.Spacing.xxxl)

                    // Form
                    VStack(spacing: AppTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Email")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                        }

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Password")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SecureField("••••••••", text: $password)
                                .textContentType(.password)
                                .padding(AppTheme.Spacing.md)
                                .background(AppTheme.Colors.surface)
                                .clipShape(.rect(cornerRadius: AppTheme.Radius.sm))
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.xxl)

                    // Login Button
                    Button {
                        Task {
                            do {
                                try await authManager.login(email: email, password: password)
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
                                Text("Sign In")
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

                    // Debug: show error inline
                    if let errorMsg = authManager.error {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppTheme.Spacing.xxl)
                            .multilineTextAlignment(.center)
                    }

                    // Register Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)

                        Button("Sign Up") {
                            showRegister = true
                        }
                        .foregroundStyle(AppTheme.Colors.primaryFallback)
                        .bold()
                    }
                    .font(.subheadline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("Sign In Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authManager.error ?? "Please check your credentials and try again.")
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
}

#Preview {
    LoginView()
        .environment(AuthManager.shared)
}
