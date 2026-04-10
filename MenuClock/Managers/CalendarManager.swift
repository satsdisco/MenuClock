import Foundation
import EventKit
import AppKit

@MainActor
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let store = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus
    @Published var upcomingEvents: [EKEvent] = []
    @Published var availableCalendars: [EKCalendar] = []

    private var refreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?

    private init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }

        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        refreshTimer = t
        RunLoop.main.add(t, forMode: .common)

        Task { await requestAccessIfNeeded() }
    }

    var isAuthorized: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    func requestAccessIfNeeded() async {
        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToEvents()
            } else {
                _ = try await store.requestAccess(to: .event)
            }
        } catch {
            // Keep current status; user will see the empty/denied UI.
        }
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized {
            await refresh()
        }
    }

    func refresh() async {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else {
            self.upcomingEvents = []
            self.availableCalendars = []
            return
        }

        // Snapshot the user's calendars (sorted: source name, then title) so
        // the picker UI in Settings has a stable list.
        let cals = store.calendars(for: .event)
            .sorted { lhs, rhs in
                if lhs.source.title != rhs.source.title {
                    return lhs.source.title.localizedCaseInsensitiveCompare(rhs.source.title) == .orderedAscending
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        self.availableCalendars = cals

        let settings = SettingsManager.shared
        let defaults = UserDefaults.standard

        // First-run: enable everything so the dropdown is useful out of the box.
        // After this point the set is the literal source of truth — empty = none.
        if !defaults.bool(forKey: "calendarPickerInitialized") {
            settings.enabledCalendarIdentifiers = Set(cals.map(\.calendarIdentifier))
            defaults.set(true, forKey: "calendarPickerInitialized")
        }

        let calendarsToQuery = cals.filter {
            settings.enabledCalendarIdentifiers.contains($0.calendarIdentifier)
        }
        if calendarsToQuery.isEmpty {
            self.upcomingEvents = []
            return
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now)
            ?? now.addingTimeInterval(30 * 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendarsToQuery)

        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)

        self.upcomingEvents = Array(events)
    }

    func openCalendarApp() {
        if let url = URL(string: "ical://") {
            NSWorkspace.shared.open(url)
        }
    }
}
