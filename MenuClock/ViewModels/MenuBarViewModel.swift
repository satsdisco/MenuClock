import Foundation
import Combine

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var title: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let settings: SettingsManager
    private let ticker: ClockTicker

    init(settings: SettingsManager = .shared, ticker: ClockTicker = .shared) {
        self.settings = settings
        self.ticker = ticker

        let recompute: () -> Void = { [weak self] in
            guard let self else { return }
            self.title = Self.compute(now: self.ticker.now, settings: self.settings)
        }

        ticker.$now
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$menuBarMode
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$worldClocks
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$secondaryClockID
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$showPrimaryLabel
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$menuBarSeparator
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$timeFormat
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        settings.$menuBarDateStyle
            .receive(on: RunLoop.main)
            .sink { _ in recompute() }
            .store(in: &cancellables)

        recompute()
    }

    static func compute(now: Date, settings: SettingsManager) -> String {
        let style = settings.timeFormat
        var result: String

        switch settings.menuBarMode {
        case .primaryOnly:
            result = TimeFormatting.timeString(for: now, in: .current, style: style)

        case .primaryPlusSecondary:
            let primaryTime = TimeFormatting.timeString(for: now, in: .current, style: style)
            guard let secondary = settings.secondaryClock else {
                result = primaryTime
                break
            }

            let secondaryTZ = TimeZone(identifier: secondary.timeZoneIdentifier) ?? .current
            let secondaryTime = TimeFormatting.timeString(for: now, in: secondaryTZ, style: style)

            // Primary part — optionally prefixed with local city code
            let primaryPart: String
            if settings.showPrimaryLabel {
                primaryPart = "\(shortCode(forTimeZone: .current)) \(primaryTime)"
            } else {
                primaryPart = primaryTime
            }

            // Secondary part — always labeled with a short code
            let secondaryCode = shortCode(fromLabel: secondary.label)
                ?? shortCode(forTimeZone: secondaryTZ)
            let secondaryPart = "\(secondaryCode) \(secondaryTime)"

            // Stitch with the chosen separator. Space-only gets extra padding.
            let rawSep = settings.menuBarSeparator.rawValue
            let separator = settings.menuBarSeparator == .space ? "  " : " \(rawSep) "
            result = primaryPart + separator + secondaryPart
        }

        // Prepend date if enabled
        if let template = settings.menuBarDateStyle.dateTemplate {
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = .current
            df.setLocalizedDateFormatFromTemplate(template)
            result = df.string(from: now) + "  " + result
        }

        return result
    }


    /// Derive a 3-letter code from an IANA identifier's city component,
    /// e.g. "America/New_York" → "NEW", "Asia/Tokyo" → "TOK".
    private static func shortCode(forTimeZone tz: TimeZone) -> String {
        if let city = tz.identifier.split(separator: "/").last {
            let cleaned = city.replacingOccurrences(of: "_", with: " ")
            return String(cleaned.prefix(3)).uppercased()
        }
        return tz.abbreviation() ?? ""
    }

    /// Derive a compact code from a user-provided label.
    /// Multi-word labels → initials ("New York" → "NY", "San Francisco" → "SF").
    /// Single-word labels → first 3 characters ("Meridian" → "MER").
    /// Returns nil for empty labels so the caller can fall back.
    private static func shortCode(fromLabel label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let words = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            let initials = words
                .prefix(3)
                .compactMap { $0.first.map { String($0) } }
                .joined()
            return initials.uppercased()
        }
        return String(trimmed.prefix(3)).uppercased()
    }
}
