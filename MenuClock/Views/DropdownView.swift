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
                ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                    EventRow(event: event)
                }
            }
            .padding(.horizontal, 12)
        }
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
