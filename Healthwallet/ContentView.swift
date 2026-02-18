//
//  ContentView.swift
//  Healthwallet
//
//  Created by oj on 24.01.26.
//

import SwiftUI

struct ContentView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isBootstrapping {
                // Splash/Loading screen
                VStack(spacing: AppTheme.Spacing.lg) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.Colors.primaryFallback)

                    ProgressView()
                }
            } else if authManager.isAuthenticated {
                if authManager.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }
        }
        .environment(authManager)
    }
}

#Preview {
    ContentView()
}
