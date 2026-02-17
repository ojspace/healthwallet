import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    // MARK: - Published State
    private(set) var records: [HealthRecord] = []
    private(set) var weeklyFocusItems: [WeeklyFocus] = []
    var showUploadSheet = false
    var selectedBiomarker: Biomarker?
    private(set) var isLoading = false
    private(set) var error: String?

    // Dashboard data from API
    private(set) var dashboardData: DashboardResponse?
    private(set) var healthAge: Int?
    private(set) var chronologicalAge: Int?
    private(set) var summary: String?

    // Quick Log / Habit Tracking
    private(set) var todayLogged = false
    private(set) var streak: StreakResponse?

    // MARK: - Computed Properties

    var latestRecord: HealthRecord? {
        records.first
    }

    var latestBiomarkers: [Biomarker] {
        latestRecord?.biomarkers ?? []
    }

    var latestCheckInDate: String {
        if let lastSync = dashboardData?.lastSync {
            return lastSync
        }
        return latestRecord?.date.formatted(.dateTime.month(.wide).day().year()) ?? "No records"
    }

    var hasRecords: Bool {
        !records.isEmpty && !latestBiomarkers.isEmpty
    }

    var focusSummary: String {
        if let summary = dashboardData?.summary {
            return summary
        }
        let flags = latestBiomarkers.filter { $0.status != .optimal }
        let names = flags.map { "\($0.status.rawValue.lowercased()) \($0.name)" }
        guard !names.isEmpty else { return "All biomarkers look great!" }
        return "Based on your \(names.joined(separator: " and "))."
    }

    var wellnessScore: Int {
        if let score = dashboardData?.wellnessScore {
            return score
        }
        guard !latestBiomarkers.isEmpty else { return 0 }
        var score = 100
        for biomarker in latestBiomarkers {
            if biomarker.status != .optimal {
                score -= 10
            }
        }
        return max(0, min(100, score))
    }

    // MARK: - Initialization

    init() {
        // Start with empty state - will fetch from API
    }

    // MARK: - API Methods

    func fetchRecords() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Fetch records first, then dashboard
            let response = try await RecordsService.shared.listRecords()
            await fetchDashboard()

            records = response.records
                .filter { $0.status == .completed }
                .map { $0.toHealthRecord() }

            await fetchWeeklyFocus()
            await fetchTodayStatus()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshData() async {
        await fetchRecords()
        await fetchTodayStatus()
    }

    func fetchTodayStatus() async {
        do {
            let response: QuickLogListResponse = try await APIClient.shared.get("/logs")
            let today = Self.todayDateString()
            todayLogged = response.logs.contains(where: { $0.date == today })

            let streakData: StreakResponse = try await APIClient.shared.get("/logs/streak")
            streak = streakData
        } catch {
            // Non-critical — don't fail the whole home screen
        }
    }

    func markTodayLogged() {
        todayLogged = true
        // Refresh streak after a short delay to let backend process
        Task {
            try? await Task.sleep(for: .seconds(1))
            do {
                let streakData: StreakResponse = try await APIClient.shared.get("/logs/streak")
                streak = streakData
            } catch {
                // Non-critical — streak will refresh on next pull-to-refresh
            }
        }
    }

    // MARK: - Date Formatting

    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func todayDateString() -> String {
        todayFormatter.string(from: Date())
    }

    private func fetchDashboard() async {
        do {
            let dashboard = try await RecordsService.shared.getDashboard()
            dashboardData = dashboard
            healthAge = dashboard.healthAge
            summary = dashboard.summary
            if let dateOfBirth = AuthManager.shared.currentUser?.dateOfBirth {
                chronologicalAge = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
            }
        } catch {
            print("[HOME] Dashboard fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Weekly Focus (from backend)

    private func fetchWeeklyFocus() async {
        do {
            let response: WeeklyFocusResponse = try await APIClient.shared.get("/nutrition/weekly-focus")
            weeklyFocusItems = response.items.map { item in
                WeeklyFocus(
                    title: item.title,
                    subtitle: item.subtitle,
                    iconName: item.iconName,
                    actionLabel: item.actionLabel,
                    actionType: FocusActionType(rawValue: item.actionType) ?? .tip,
                    reminderName: item.reminderName,
                    reminderTiming: item.reminderTiming,
                    reminderHour: item.reminderHour
                )
            }
            if !response.summary.isEmpty {
                // Use backend summary if available
            }
        } catch {
            print("[HOME] Weekly focus fetch failed: \(error.localizedDescription)")
        }
    }

}
