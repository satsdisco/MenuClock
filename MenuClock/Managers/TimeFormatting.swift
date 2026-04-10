import Foundation

/// Single source of truth for turning a `Date` into a short "time of day"
/// string anywhere in the app, honoring the user's 12h/24h override.
enum TimeFormatting {
    static func timeString(
        for date: Date,
        in timeZone: TimeZone,
        style: TimeFormatStyle = SettingsManager.shared.timeFormat
    ) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = timeZone
        df.setLocalizedDateFormatFromTemplate(style.dateTemplate)
        return df.string(from: date)
    }
}
