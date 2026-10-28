import Foundation

@main
struct MenuBarTests {
    @MainActor
    static func main() throws {
        // This standalone executable has its own defaults domain, separate from
        // com.menuclock.MenuClock. Restore any previous test preferences on exit.
        let defaults = UserDefaults.standard
        let keys = ["menuBarMode", "worldClocks", "secondaryClockID", "timeFormat",
                    "menuBarDateStyle", "menuBarClockOrder", "menuBarSeparator",
                    "showPrimaryLabel", "menuBarDatePosition"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        var checks = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        for raw in ["primaryOnly", "primaryPlusSecondary", "secondaryOnly"] {
            let mode = try JSONDecoder().decode(MenuBarMode.self, from: Data("\"\(raw)\"".utf8))
            expect(mode.rawValue == raw, "Saved enum value changed: \(raw)")
            expect(try JSONEncoder().encode(mode) == Data("\"\(raw)\"".utf8), "Enum round trip failed")
        }
        defaults.set("secondaryOnly", forKey: "menuBarMode")
        let settings = SettingsManager.shared
        expect(settings.menuBarMode == .secondaryOnly, "New mode must load from saved preferences")
        settings.menuBarDateStyle = .hidden
        settings.showPrimaryLabel = false
        settings.menuBarSeparator = .pipe
        settings.menuBarClockOrder = .secondaryFirst
        let tokyo = WorldClock(timeZoneIdentifier: "Asia/Tokyo", label: "Tokyo")
        let newYork = WorldClock(timeZoneIdentifier: "America/New_York", label: "New York")
        settings.worldClocks = [newYork, tokyo]
        settings.secondaryClockID = tokyo.id
        // Tokyo is on the next calendar day at this instant.
        let now = ISO8601DateFormatter().date(from: "2026-01-01T23:30:00Z")!
        func title() -> String { MenuBarViewModel.compute(now: now, settings: settings) }
        func time(_ zone: TimeZone) -> String {
            TimeFormatting.timeString(for: now, in: zone, style: settings.timeFormat)
        }

        for style in TimeFormatStyle.allCases {
            settings.timeFormat = style
            expect(title() == "TOK \(time(tokyo.timeZone))", "Secondary mode must honor selected clock and time format")
        }
        settings.menuBarDateStyle = .medium
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = tokyo.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let date = formatter.string(from: now)
        settings.menuBarDatePosition = .leading
        expect(title() == "\(date)  TOK \(time(tokyo.timeZone))", "Leading date must use secondary timezone")
        settings.menuBarDatePosition = .trailing
        expect(title() == "TOK \(time(tokyo.timeZone))  \(date)", "Trailing date must use secondary timezone")
        settings.menuBarDateStyle = .hidden

        settings.menuBarMode = .primaryOnly
        expect(title() == time(.current), "Local-only mode must remain unchanged")
        settings.menuBarMode = .primaryPlusSecondary
        expect(title() == "TOK \(time(tokyo.timeZone)) | \(time(.current))", "Dual mode order and separator must remain unchanged")
        settings.menuBarClockOrder = .localFirst
        settings.menuBarSeparator = .space
        expect(title() == "\(time(.current))  TOK \(time(tokyo.timeZone))", "Dual mode local-first and spacing")
        let dualTitle = title()
        settings.menuBarMode = .secondaryOnly
        expect(title() == "TOK \(time(tokyo.timeZone))", "Single mode ignores dual-clock controls")
        settings.menuBarMode = .primaryPlusSecondary
        expect(title() == dualTitle, "Switching modes must retain dual-clock settings")
        settings.menuBarMode = .secondaryOnly
        expect(defaults.string(forKey: "menuBarMode") == "secondaryOnly", "New mode must persist")

        settings.secondaryClockID = UUID()
        expect(title() == "NY \(time(newYork.timeZone))", "Deleted selection must fall back to first clock")
        settings.worldClocks = [WorldClock(timeZoneIdentifier: "Asia/Tokyo", label: "  ")]
        expect(title() == "TOK \(time(tokyo.timeZone))", "Empty label must use timezone city code")
        settings.worldClocks = [WorldClock(timeZoneIdentifier: "invalid/timezone", label: "Fallback")]
        expect(title() == "FAL \(time(.current))", "Invalid timezone must fall back safely")
        settings.worldClocks = []
        expect(title() == time(.current), "No clocks must fall back to local time")
        expect(settings.menuBarMode == .secondaryOnly, "Fallback must retain selected mode")
        settings.menuBarMode = .primaryPlusSecondary
        expect(title() == time(.current), "Existing dual-mode fallback must remain unchanged")
        print("Passed \(checks) menu bar regression checks")
    }
}
