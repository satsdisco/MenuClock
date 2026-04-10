import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var weatherManager: WeatherManager
    @EnvironmentObject var ticker: ClockTicker
    @EnvironmentObject var calendarManager: CalendarManager
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                generalSection
                    .padding(16)
                Divider()
                menuBarSection
                    .padding(16)
                Divider()
                weatherSection
                    .padding(16)
                Divider()
                eventsSection
                    .padding(16)
                Divider()
                worldClocksSection
            }
        }
        .frame(width: 540, height: 720)
        .sheet(isPresented: $showingAdd) {
            TimeZonePickerView { city in
                settings.add(WorldClock(
                    timeZoneIdentifier: city.timeZoneIdentifier,
                    label: city.name,
                    latitude: city.latitude,
                    longitude: city.longitude
                ))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("MenuClock")
                .font(.headline)
            Spacer()
            Button {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showAbout()
                }
            } label: {
                Label("About", systemImage: "info.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("About MenuClock")
        }
        .padding(16)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General")
                .font(.subheadline.weight(.semibold))

            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .font(.callout)

            if let err = launchAtLogin.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Time format:")
                    .font(.callout)
                Picker("", selection: $settings.timeFormat) {
                    ForEach(TimeFormatStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            HStack {
                Text("Show date:")
                    .font(.callout)
                Picker("", selection: $settings.menuBarDateStyle) {
                    ForEach(MenuBarDateStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calendar Events")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if calendarManager.isAuthorized && !calendarManager.availableCalendars.isEmpty {
                    Text(enabledSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if !calendarManager.isAuthorized {
                Text("Calendar access not granted yet — open the menu bar dropdown and click \"Grant Access\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if calendarManager.availableCalendars.isEmpty {
                Text("No calendars found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    Button("Enable All") { setAll(enabled: true) }
                    Button("Disable All") { setAll(enabled: false) }
                }
                .buttonStyle(.link)
                .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(groupedCalendars, id: \.0) { group in
                        CalendarSourceDisclosure(
                            sourceTitle: group.0,
                            calendars: group.1,
                            enabledIDs: $settings.enabledCalendarIdentifiers,
                            allCalendars: calendarManager.availableCalendars,
                            onChange: { Task { await calendarManager.refresh() } }
                        )
                    }
                }
            }
        }
        .task {
            await calendarManager.refresh()
        }
    }

    private var groupedCalendars: [(String, [EKCalendar])] {
        let groups = Dictionary(grouping: calendarManager.availableCalendars) { $0.source.title }
        return groups
            .map { key, value in
                (key, value.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                })
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private var enabledSummary: String {
        let total = calendarManager.availableCalendars.count
        let enabled: Int
        if settings.enabledCalendarIdentifiers.isEmpty {
            enabled = total
        } else {
            // Count only those that still exist (defensive against removed calendars).
            let valid = Set(calendarManager.availableCalendars.map(\.calendarIdentifier))
            enabled = settings.enabledCalendarIdentifiers.intersection(valid).count
        }
        return "\(enabled) of \(total) on"
    }

    private func setAll(enabled: Bool) {
        let allIDs = Set(calendarManager.availableCalendars.map(\.calendarIdentifier))
        settings.enabledCalendarIdentifiers = enabled ? allIDs : []
        Task { await calendarManager.refresh() }
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu Bar Display")
                .font(.subheadline.weight(.semibold))

            Picker("", selection: $settings.menuBarMode) {
                ForEach(MenuBarMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if settings.menuBarMode == .primaryPlusSecondary {
                if settings.worldClocks.isEmpty {
                    Text("Add a world clock below to pick a secondary clock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Secondary:")
                                .font(.callout)
                            Picker("", selection: secondaryBinding) {
                                ForEach(settings.worldClocks) { clock in
                                    Text(clock.displayName).tag(Optional(clock.id))
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 240)
                        }

                        HStack {
                            Text("Separator:")
                                .font(.callout)
                            Picker("", selection: $settings.menuBarSeparator) {
                                ForEach(MenuBarSeparator.allCases) { sep in
                                    Text(sep.displayName).tag(sep)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 240)
                        }

                        Toggle("Show local time zone label", isOn: $settings.showPrimaryLabel)
                            .font(.callout)

                        menuBarPreview
                    }
                }
            }
        }
    }

    private var menuBarPreview: some View {
        HStack(spacing: 8) {
            Text("Preview:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MenuBarViewModel.compute(now: ticker.now, settings: settings))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                )
        }
        .padding(.top, 4)
    }

    private var secondaryBinding: Binding<UUID?> {
        Binding(
            get: { settings.secondaryClockID ?? settings.worldClocks.first?.id },
            set: { settings.secondaryClockID = $0 }
        )
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weather")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("", isOn: $settings.weatherEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: settings.weatherEnabled) { enabled in
                        if enabled {
                            Task { await weatherManager.refreshAll(force: true) }
                        }
                    }
            }

            Text("Show current temperature next to each world clock. Uses Open-Meteo (free, no account, no tracking). Network access required.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.weatherEnabled {
                HStack {
                    Text("Temperature unit:")
                        .font(.callout)
                    Picker("", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                    .onChange(of: settings.temperatureUnit) { _ in
                        Task { await weatherManager.refreshAll(force: true) }
                    }
                }
            }
        }
    }

    private var worldClocksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("World Clocks")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(16)

            List {
                ForEach(settings.worldClocks) { clock in
                    SettingsClockRow(
                        clock: clock,
                        onLabelChange: { newLabel in
                            settings.updateLabel(id: clock.id, label: newLabel)
                        },
                        onDelete: {
                            settings.worldClocks.removeAll { $0.id == clock.id }
                        }
                    )
                }
                .onMove { from, to in
                    settings.move(from: from, to: to)
                }
                .onDelete { idx in
                    settings.remove(at: idx)
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Calendar source disclosure

struct CalendarSourceDisclosure: View {
    let sourceTitle: String
    let calendars: [EKCalendar]
    @Binding var enabledIDs: Set<String>
    let allCalendars: [EKCalendar]
    let onChange: () -> Void

    @State private var isExpanded = false

    private var enabledInGroup: Int {
        calendars.filter { enabledIDs.contains($0.calendarIdentifier) }.count
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    calendarRow(cal)
                }
                HStack(spacing: 12) {
                    Button("All") { setAll(true) }
                    Button("None") { setAll(false) }
                }
                .buttonStyle(.link)
                .font(.caption)
                .padding(.top, 2)
            }
            .padding(.leading, 18)
            .padding(.top, 2)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sourceIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(sourceTitle)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(enabledInGroup)/\(calendars.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
    }

    private var sourceIcon: String {
        let s = sourceTitle.lowercased()
        if s.contains("icloud") { return "icloud" }
        if s.contains("google") { return "g.circle" }
        if s.contains("exchange") || s.contains("office") || s.contains("outlook") {
            return "building.2"
        }
        if s.contains("subscribed") || s.contains("subscription") { return "antenna.radiowaves.left.and.right" }
        if s.contains("local") || s.contains("on my") { return "internaldrive" }
        return "calendar"
    }

    private func calendarRow(_ cal: EKCalendar) -> some View {
        let id = cal.calendarIdentifier
        let isOn = Binding<Bool>(
            get: { enabledIDs.contains(id) },
            set: { newValue in
                if newValue {
                    enabledIDs.insert(id)
                } else {
                    enabledIDs.remove(id)
                }
                onChange()
            }
        )
        return Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(nsColor: cal.color))
                    .frame(width: 8, height: 8)
                Text(cal.title)
                    .font(.system(size: 12))
            }
        }
        .toggleStyle(.checkbox)
    }

    private func setAll(_ enabled: Bool) {
        let ids = calendars.map(\.calendarIdentifier)
        if enabled {
            enabledIDs.formUnion(ids)
        } else {
            enabledIDs.subtract(ids)
        }
        onChange()
    }
}

struct SettingsClockRow: View {
    let clock: WorldClock
    let onLabelChange: (String) -> Void
    let onDelete: () -> Void

    @State private var label: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Label", text: $label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .onChange(of: label) { newValue in
                        onLabelChange(newValue)
                    }
                Text(clock.timeZoneIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .onAppear {
            label = clock.label.isEmpty
                ? WorldClock.prettify(identifier: clock.timeZoneIdentifier)
                : clock.label
        }
    }
}
