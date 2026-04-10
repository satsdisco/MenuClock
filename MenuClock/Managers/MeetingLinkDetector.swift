import Foundation
import EventKit

/// Detects video meeting URLs in calendar events by inspecting the URL,
/// location, and notes fields for known patterns.
enum MeetingLinkDetector {
    struct MeetingLink {
        let url: URL
        let provider: Provider
    }

    enum Provider: String {
        case zoom       = "Zoom"
        case googleMeet = "Google Meet"
        case teams      = "Teams"
        case webex      = "Webex"
        case generic    = "Video Call"

        var sfSymbol: String {
            switch self {
            case .zoom:       return "video.fill"
            case .googleMeet: return "video.fill"
            case .teams:      return "video.fill"
            case .webex:      return "video.fill"
            case .generic:    return "video.fill"
            }
        }
    }

    /// Try to find a meeting link in the event. Checks URL first (most
    /// reliable), then location, then notes.
    static func detect(in event: EKEvent) -> MeetingLink? {
        // 1. Event URL (set by calendar integrations)
        if let urlString = event.url?.absoluteString,
           let link = parse(urlString) {
            return link
        }

        // 2. Location field (Google Calendar often puts Meet links here)
        if let location = event.location,
           let link = findFirstLink(in: location) {
            return link
        }

        // 3. Notes / description (often contains "Join Zoom Meeting" etc.)
        if let notes = event.notes,
           let link = findFirstLink(in: notes) {
            return link
        }

        return nil
    }

    // MARK: - Parsing

    private static let patterns: [(regex: String, provider: Provider)] = [
        // Zoom
        (#"https?://[\w.-]*zoom\.us/j/\S+"#,                    .zoom),
        (#"https?://[\w.-]*zoom\.us/my/\S+"#,                   .zoom),
        // Google Meet
        (#"https?://meet\.google\.com/[\w-]+"#,                  .googleMeet),
        // Microsoft Teams
        (#"https?://teams\.microsoft\.com/l/meetup-join/\S+"#,   .teams),
        (#"https?://teams\.live\.com/meet/\S+"#,                 .teams),
        // Webex
        (#"https?://[\w.-]*\.webex\.com/\S+"#,                   .webex),
    ]

    private static func parse(_ urlString: String) -> MeetingLink? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        for (pattern, provider) in patterns {
            if let range = trimmed.range(of: pattern, options: .regularExpression),
               let url = URL(string: String(trimmed[range])) {
                return MeetingLink(url: url, provider: provider)
            }
        }
        // Generic: any https URL that looks like a meeting
        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           meetingHosts.contains(where: { host.contains($0) }) {
            return MeetingLink(url: url, provider: .generic)
        }
        return nil
    }

    /// Scan a block of text for the first meeting URL.
    private static func findFirstLink(in text: String) -> MeetingLink? {
        // Try known patterns first
        for (pattern, provider) in patterns {
            if let range = text.range(of: pattern, options: .regularExpression),
               let url = URL(string: String(text[range]).trimmingCharacters(in: .init(charactersIn: "<>\""))) {
                return MeetingLink(url: url, provider: provider)
            }
        }
        return nil
    }

    private static let meetingHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com",
        "teams.live.com", "webex.com", "whereby.com",
        "around.co", "gather.town", "cal.com"
    ]
}
