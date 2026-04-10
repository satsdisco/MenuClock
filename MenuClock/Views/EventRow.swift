import SwiftUI
import EventKit
import AppKit

struct EventRow: View {
    let event: EKEvent
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color.secondary.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            openInCalendarApp()
        }
    }

    /// Try to open Calendar.app at this specific event. The undocumented but
    /// long-standing scheme `ical://ekevent/<calendarItemIdentifier>` works for
    /// local events. Falls back to opening Calendar.app generically.
    private func openInCalendarApp() {
        let id = event.calendarItemIdentifier
        if !id.isEmpty,
           let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "ical://ekevent/\(encoded)?method=show&options=more") {
            if NSWorkspace.shared.open(url) { return }
        }
        if let fallback = URL(string: "ical://") {
            NSWorkspace.shared.open(fallback)
        }
    }

    private var timeString: String {
        let cal = Calendar.current
        let time = TimeFormatting.timeString(for: event.startDate, in: .current)

        if cal.isDateInToday(event.startDate) {
            return "Today · \(time)"
        } else if cal.isDateInTomorrow(event.startDate) {
            return "Tomorrow · \(time)"
        } else {
            // Include weekday + month/day alongside the styled time.
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = .current
            df.setLocalizedDateFormatFromTemplate("EEEMMMd")
            return "\(df.string(from: event.startDate)) · \(time)"
        }
    }
}
