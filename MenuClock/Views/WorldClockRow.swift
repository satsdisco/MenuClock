import SwiftUI

struct WorldClockRow: View {
    let clock: WorldClock
    let now: Date
    let weather: WeatherSnapshot?
    var isLocal: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if isLocal {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tint)
                    }
                    Text(clock.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                Text(isLocal ? "Local" : dayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let weather {
                HStack(spacing: 3) {
                    Image(systemName: weather.sfSymbol)
                        .font(.system(size: 11))
                        .symbolRenderingMode(.multicolor)
                    Text(weather.formattedTemperature)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }

            Text(timeString)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    private var timeString: String {
        TimeFormatting.timeString(for: now, in: clock.timeZone)
    }

    private var dayLabel: String {
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        var remoteCal = Calendar(identifier: .gregorian)
        remoteCal.timeZone = clock.timeZone

        let localComps = localCal.dateComponents([.year, .month, .day], from: now)
        let remoteComps = remoteCal.dateComponents([.year, .month, .day], from: now)

        var neutral = Calendar(identifier: .gregorian)
        neutral.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard let localDate = neutral.date(from: localComps),
              let remoteDate = neutral.date(from: remoteComps) else {
            return ""
        }

        let diff = neutral.dateComponents([.day], from: localDate, to: remoteDate).day ?? 0
        switch diff {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default:
            let fmt = DateFormatter()
            fmt.locale = .current
            fmt.timeZone = clock.timeZone
            fmt.setLocalizedDateFormatFromTemplate("EEEMMMd")
            return fmt.string(from: now)
        }
    }
}
