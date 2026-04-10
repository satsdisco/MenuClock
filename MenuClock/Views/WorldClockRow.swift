import SwiftUI

struct WorldClockRow: View {
    let clock: WorldClock
    let now: Date
    let weather: WeatherSnapshot?
    var isLocal: Bool = false

    private var remoteHour: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = clock.timeZone
        return cal.component(.hour, from: now)
    }

    /// Daytime = 7 AM to 9 PM (generous), everything else is night.
    private var isDaytime: Bool {
        (7..<21).contains(remoteHour)
    }

    private var dayNightSymbol: String {
        switch remoteHour {
        case 6..<8:   return "sunrise.fill"
        case 8..<18:  return "sun.max.fill"
        case 18..<21: return "sunset.fill"
        default:      return "moon.fill"
        }
    }

    private var dayNightColor: Color {
        switch remoteHour {
        case 6..<8:   return .orange
        case 8..<18:  return .yellow
        case 18..<21: return .orange
        default:      return .indigo
        }
    }

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
                HStack(spacing: 4) {
                    Image(systemName: dayNightSymbol)
                        .font(.system(size: 8))
                        .foregroundStyle(dayNightColor)
                    Text(isLocal ? "Local" : dayLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
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
                .foregroundStyle(isDaytime ? .primary : .secondary)
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
