import Foundation
import EventKit
import Observation
import UIKit

@Observable
@MainActor
final class CalendarManager {
    static let shared = CalendarManager()

    let eventStore = EKEventStore()
    var isAuthorized = false
    var error: String?

    private let calendarTitle = "HealthWallet Supplements"

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = (status == .fullAccess)
    }

    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
        } else {
            let granted = try await eventStore.requestAccess(to: .event)
            isAuthorized = granted
        }

        if !isAuthorized {
            throw CalendarError.accessDenied
        }
    }

    // MARK: - Calendar Management

    /// Get or create the dedicated HealthWallet calendar
    private func getOrCreateCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = UIColor.systemGreen.cgColor

        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            throw CalendarError.noCalendarSource
        }

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    // MARK: - Supplement Reminders

    /// Add a recurring daily supplement reminder for 90 days
    func addSupplementReminder(
        name: String,
        timing: String,
        timingNote: String,
        hour: Int
    ) async throws {
        if !isAuthorized {
            try await requestAccess()
        }

        let calendar = try getOrCreateCalendar()

        // Deduplicate: skip if an event with same title already exists today
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate)

        let eventTitle = "\u{1F48A} \(name)"
        if existingEvents.contains(where: { $0.title == eventTitle }) {
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = eventTitle
        event.notes = timingNote
        event.calendar = calendar

        // Set start time today at the specified hour
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        event.startDate = Calendar.current.date(from: components)!
        event.endDate = Calendar.current.date(byAdding: .minute, value: 15, to: event.startDate)!

        // Repeat daily for 90 days
        let recurrenceEnd = EKRecurrenceEnd(end: Calendar.current.date(byAdding: .day, value: 90, to: Date())!)
        let rule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: recurrenceEnd
        )
        event.addRecurrenceRule(rule)

        // Alert 5 minutes before
        event.addAlarm(EKAlarm(relativeOffset: -300))

        try eventStore.save(event, span: .futureEvents)
    }

    /// Add all supplement reminders from a list of recommendations
    func addAllReminders(from recommendations: [SupplementRecommendation]) async throws {
        for rec in recommendations {
            try await addSupplementReminder(
                name: rec.name,
                timing: rec.timing,
                timingNote: rec.timingNote,
                hour: rec.calendarHour
            )
        }
    }

    /// Remove the entire HealthWallet calendar and all its events
    func removeAllEvents() throws {
        let calendars = eventStore.calendars(for: .event)
        guard let calendar = calendars.first(where: { $0.title == calendarTitle }) else {
            return
        }
        try eventStore.removeCalendar(calendar, commit: true)
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case accessDenied
    case noCalendarSource

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Please enable it in Settings."
        case .noCalendarSource:
            return "Could not find a calendar source on this device."
        }
    }
}
