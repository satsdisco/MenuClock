import Foundation

enum MenuBarMode: String, Codable, CaseIterable, Identifiable {
    case primaryOnly
    case primaryPlusSecondary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primaryOnly: return "Local time only"
        case .primaryPlusSecondary: return "Local + secondary clock"
        }
    }
}

enum TimeFormatStyle: String, Codable, CaseIterable, Identifiable {
    case automatic      // follow system locale
    case twelveHour     // always 12h with AM/PM
    case twentyFourHour // always 24h

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:      return "Automatic (follow system)"
        case .twelveHour:     return "12-hour (1:45 PM)"
        case .twentyFourHour: return "24-hour (13:45)"
        }
    }

    /// DateFormatter template for a short time string under this style.
    /// "jmm" = locale-preferred, "hmm" = forced 12h, "Hmm" = forced 24h.
    var dateTemplate: String {
        switch self {
        case .automatic:      return "jmm"
        case .twelveHour:     return "hmm"
        case .twentyFourHour: return "Hmm"
        }
    }
}

enum MenuBarSeparator: String, Codable, CaseIterable, Identifiable {
    case bullet     = "•"
    case middleDot  = "·"
    case pipe       = "|"
    case dash       = "—"
    case slash      = "/"
    case space      = " "

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bullet:    return "Bullet  •"
        case .middleDot: return "Middle dot  ·"
        case .pipe:      return "Pipe  |"
        case .dash:      return "Dash  —"
        case .slash:     return "Slash  /"
        case .space:     return "Just spacing"
        }
    }
}
