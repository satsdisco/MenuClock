import Foundation

struct WorldClock: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var timeZoneIdentifier: String
    var label: String
    /// Optional — present when the clock was added via the city picker.
    /// Used for weather lookups. Existing saved clocks without coordinates
    /// decode cleanly because these are optionals.
    var latitude: Double?
    var longitude: Double?

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var displayName: String {
        label.isEmpty ? Self.prettify(identifier: timeZoneIdentifier) : label
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    static func prettify(identifier: String) -> String {
        identifier
            .split(separator: "/")
            .last
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            ?? identifier
    }
}
