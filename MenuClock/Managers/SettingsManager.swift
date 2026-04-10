import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    /// Stable synthetic ID used for the always-shown "local" clock at the top
    /// of the dropdown. Chosen so WeatherManager snapshots key cleanly by UUID.
    static let localClockID = UUID(uuidString: "00000000-0000-0000-0000-0000000C10CA")!

    @Published var worldClocks: [WorldClock] {
        didSet { persistClocks() }
    }

    @Published var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Keys.menuBarMode)
        }
    }

    @Published var secondaryClockID: UUID? {
        didSet {
            if let id = secondaryClockID {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.secondaryID)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.secondaryID)
            }
        }
    }

    @Published var weatherEnabled: Bool {
        didSet { UserDefaults.standard.set(weatherEnabled, forKey: Keys.weatherEnabled) }
    }

    @Published var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    @Published var showPrimaryLabel: Bool {
        didSet { UserDefaults.standard.set(showPrimaryLabel, forKey: Keys.showPrimaryLabel) }
    }

    @Published var menuBarDateStyle: MenuBarDateStyle {
        didSet { UserDefaults.standard.set(menuBarDateStyle.rawValue, forKey: Keys.menuBarDateStyle) }
    }

    @Published var menuBarSeparator: MenuBarSeparator {
        didSet { UserDefaults.standard.set(menuBarSeparator.rawValue, forKey: Keys.menuBarSeparator) }
    }

    @Published var timeFormat: TimeFormatStyle {
        didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: Keys.timeFormat) }
    }

    /// Identifiers of calendars that should contribute events to the dropdown.
    /// Empty set means "all calendars" — sane first-run default.
    @Published var enabledCalendarIdentifiers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIdentifiers), forKey: Keys.enabledCalendarIDs)
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var secondaryClock: WorldClock? {
        if let id = secondaryClockID,
           let match = worldClocks.first(where: { $0.id == id }) {
            return match
        }
        return worldClocks.first
    }

    /// A synthetic "local" WorldClock derived from the system time zone,
    /// with coordinates resolved via the bundled city database so weather
    /// can be fetched for it. Not persisted.
    var localClock: WorldClock {
        let tz = TimeZone.current
        let identifier = tz.identifier
        let city = CityDatabase.shared.city(forTimeZone: identifier)
        return WorldClock(
            id: Self.localClockID,
            timeZoneIdentifier: identifier,
            label: city?.name ?? WorldClock.prettify(identifier: identifier),
            latitude: city?.latitude,
            longitude: city?.longitude
        )
    }

    private enum Keys {
        static let worldClocks = "worldClocks"
        static let menuBarMode = "menuBarMode"
        static let secondaryID = "secondaryClockID"
        static let weatherEnabled = "weatherEnabled"
        static let temperatureUnit = "temperatureUnit"
        static let showPrimaryLabel = "showPrimaryLabel"
        static let menuBarDateStyle = "menuBarDateStyle"
        static let menuBarSeparator = "menuBarSeparator"
        static let timeFormat = "timeFormat"
        static let enabledCalendarIDs = "enabledCalendarIDs"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private init() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Keys.worldClocks),
           let decoded = try? JSONDecoder().decode([WorldClock].self, from: data) {
            self.worldClocks = decoded
        } else {
            self.worldClocks = SettingsManager.defaultClocks()
        }

        if let raw = defaults.string(forKey: Keys.menuBarMode),
           let mode = MenuBarMode(rawValue: raw) {
            self.menuBarMode = mode
        } else {
            self.menuBarMode = .primaryOnly
        }

        if let idStr = defaults.string(forKey: Keys.secondaryID),
           let uuid = UUID(uuidString: idStr) {
            self.secondaryClockID = uuid
        } else {
            self.secondaryClockID = nil
        }

        if defaults.object(forKey: Keys.weatherEnabled) != nil {
            self.weatherEnabled = defaults.bool(forKey: Keys.weatherEnabled)
        } else {
            self.weatherEnabled = false
        }

        if let raw = defaults.string(forKey: Keys.temperatureUnit),
           let unit = TemperatureUnit(rawValue: raw) {
            self.temperatureUnit = unit
        } else {
            // Default to Fahrenheit in the US, Celsius everywhere else.
            let usesMetric = Locale.current.measurementSystem != .us
            self.temperatureUnit = usesMetric ? .celsius : .fahrenheit
        }

        if defaults.object(forKey: Keys.showPrimaryLabel) != nil {
            self.showPrimaryLabel = defaults.bool(forKey: Keys.showPrimaryLabel)
        } else {
            self.showPrimaryLabel = true
        }

        if let raw = defaults.string(forKey: Keys.menuBarDateStyle),
           let style = MenuBarDateStyle(rawValue: raw) {
            self.menuBarDateStyle = style
        } else {
            self.menuBarDateStyle = .hidden
        }

        if let raw = defaults.string(forKey: Keys.menuBarSeparator),
           let sep = MenuBarSeparator(rawValue: raw) {
            self.menuBarSeparator = sep
        } else {
            self.menuBarSeparator = .middleDot
        }

        if let raw = defaults.string(forKey: Keys.timeFormat),
           let style = TimeFormatStyle(rawValue: raw) {
            self.timeFormat = style
        } else {
            self.timeFormat = .automatic
        }

        if let arr = defaults.array(forKey: Keys.enabledCalendarIDs) as? [String] {
            self.enabledCalendarIdentifiers = Set(arr)
        } else {
            self.enabledCalendarIdentifiers = []
        }

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Mutations

    func add(_ clock: WorldClock) {
        worldClocks.append(clock)
    }

    func remove(at offsets: IndexSet) {
        worldClocks.remove(atOffsets: offsets)
    }

    func move(from: IndexSet, to: Int) {
        worldClocks.move(fromOffsets: from, toOffset: to)
    }

    func updateLabel(id: UUID, label: String) {
        guard let i = worldClocks.firstIndex(where: { $0.id == id }) else { return }
        worldClocks[i].label = label
    }

    // MARK: - Persistence

    private func persistClocks() {
        guard let data = try? JSONEncoder().encode(worldClocks) else { return }
        UserDefaults.standard.set(data, forKey: Keys.worldClocks)
    }

    private static func defaultClocks() -> [WorldClock] {
        [
            WorldClock(timeZoneIdentifier: "America/New_York", label: "New York",
                       latitude: 40.7128, longitude: -74.0060),
            WorldClock(timeZoneIdentifier: "Europe/London", label: "London",
                       latitude: 51.5074, longitude: -0.1278),
            WorldClock(timeZoneIdentifier: "Asia/Tokyo", label: "Tokyo",
                       latitude: 35.6895, longitude: 139.6917)
        ]
    }
}
