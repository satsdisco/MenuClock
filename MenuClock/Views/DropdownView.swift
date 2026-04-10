import SwiftUI
import EventKit
import AppKit

struct DropdownView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var ticker: ClockTicker
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var weatherManager: WeatherManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("World Clocks")
            worldClockSection

            Divider().padding(.vertical, 10)

            sectionHeader("Upcoming Events")
            eventsSection

            Divider().padding(.vertical, 8)

            footer
        }
        .padding(.vertical, 12)
        .frame(width: 320)
        .task {
            await calendarManager.refresh()
            if settings.weatherEnabled {
                await weatherManager.refreshAll()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var worldClockSection: some View {
        let local = settings.localClock
        VStack(spacing: 2) {
            WorldClockRow(
                clock: local,
                now: ticker.now,
                weather: settings.weatherEnabled ? weatherManager.snapshot(for: local) : nil,
                isLocal: true
            )

            ForEach(settings.worldClocks) { clock in
                WorldClockRow(
                    clock: clock,
                    now: ticker.now,
                    weather: settings.weatherEnabled ? weatherManager.snapshot(for: clock) : nil
                )
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var eventsSection: some View {
        if !calendarManager.isAuthorized {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar access not granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Grant Access") {
                    Task { await calendarManager.requestAccessIfNeeded() }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal, 14)
        } else if calendarManager.upcomingEvents.isEmpty {
            emptyState("No upcoming events", systemImage: "calendar")
        } else {
            VStack(spacing: 2) {
                nextEventCountdown
                ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                    EventRow(event: event, now: ticker.now)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    /// Live countdown to (or status of) the next event.
    @ViewBuilder
    private var nextEventCountdown: some View {
        if let next = calendarManager.upcomingEvents.first {
            let now = ticker.now
            let isOngoing = next.startDate <= now && next.endDate > now

            HStack(spacing: 6) {
                Image(systemName: isOngoing ? "record.circle" : "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(isOngoing ? .red : .orange)
                if isOngoing {
                    Text("\(next.title ?? "Event") · ends \(relativeTime(until: next.endDate, from: now))")
                        .font(.system(size: 11, weight: .medium))
                } else {
                    Text("\(next.title ?? "Event") · \(relativeTime(until: next.startDate, from: now))")
                        .font(.system(size: 11, weight: .medium))
                }
                Spacer()
            }
            .lineLimit(1)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isOngoing ? Color.red.opacity(0.1) : Color.orange.opacity(0.08))
            )
            .padding(.bottom, 4)
        }
    }

    private func relativeTime(until target: Date, from now: Date) -> String {
        let seconds = Int(target.timeIntervalSince(now))
        if seconds < 0 { return "now" }
        if seconds < 60 { return "in <1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "in \(hours)h" }
        return "in \(hours)h \(mins)m"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                openWindow(id: "meeting-planner")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Meeting Planner", systemImage: "person.2.wave.2")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Button {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
    }

    private func emptyState(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
