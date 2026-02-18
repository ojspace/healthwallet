import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab = 0
    @State private var homeVM = HomeViewModel()
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: homeVM, selectedTab: $selectedTab)
                    .toolbar {
                        if !(authManager.currentUser?.isPro ?? false) {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showPaywall = true
                                } label: {
                                    Label("Upgrade", systemImage: "crown.fill")
                                        .labelStyle(.titleAndIcon)
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppTheme.Colors.primaryFallback)
                                        .clipShape(Capsule())
                                }
                                .accessibilityLabel("Upgrade to Pro")
                            }
                        }
                    }
            }
            .tag(0)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                InsightsView()
            }
            .tag(1)
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                ChatView()
            }
            .tag(2)
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
            }

            NavigationStack {
                ProfileView()
            }
            .tag(3)
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
        .tint(AppTheme.Colors.primaryFallback)
        .sheet(isPresented: $showPaywall) {
            HealthWalletPaywallView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager.shared)
}
