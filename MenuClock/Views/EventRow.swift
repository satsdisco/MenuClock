import SwiftUI
import EventKit
import AppKit

struct EventRow: View {
    let event: EKEvent
    let now: Date
    @State private var isHovering = false

    private var meetingLink: MeetingLinkDetector.MeetingLink? {
        MeetingLinkDetector.detect(in: event)
    }

    private var isOngoing: Bool {
        event.startDate <= now && event.endDate > now
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let link = meetingLink {
                Button {
                    NSWorkspace.shared.open(link.url)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: link.provider.sfSymbol)
                            .font(.system(size: 9))
                        Text("Join")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOngoing ? Color.green : Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Join \(link.provider.rawValue)")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color.secondary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture {
            openInCalendarApp()
        }
    }

    private var timeString: String {
        let cal = Calendar.current
        let time = TimeFormatting.timeString(for: event.startDate, in: .current)

        if isOngoing {
            let remaining = event.endDate.timeIntervalSince(now)
            let mins = Int(remaining / 60)
            if mins < 60 {
                return "Now · ends in \(mins)m"
            }
            let h = mins / 60
            let m = mins % 60
            return "Now · ends in \(h)h \(m)m"
        } else if cal.isDateInToday(event.startDate) {
            return "Today · \(time)"
        } else if cal.isDateInTomorrow(event.startDate) {
            return "Tomorrow · \(time)"
        } else {
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = .current
            df.setLocalizedDateFormatFromTemplate("EEEMMMd")
            return "\(df.string(from: event.startDate)) · \(time)"
        }
    }

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
}
