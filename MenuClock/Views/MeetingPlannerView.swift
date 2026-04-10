import SwiftUI
import AppKit

/// Pick any moment in time and see it rendered in every configured world clock.
/// Each row is colored by how reasonable the local hour is for a meeting.
struct MeetingPlannerView: View {
    @EnvironmentObject var settings: SettingsManager

    /// The chosen moment, normalized to today's date by default.
    @State private var selectedDate: Date = Date()

    private var allClocks: [WorldClock] {
        [settings.localClock] + settings.worldClocks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(16)

            Divider()

            picker
                .padding(16)

            Divider()

            results
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            Divider()

            footer
                .padding(12)
        }
        .frame(width: 540, height: 540)
        .onAppear {
            selectedDate = Self.roundToNearestQuarter(Date())
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.wave.2.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Meeting Planner")
                    .font(.headline)
                Text("Find a time that works across every world clock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                DatePicker("",
                           selection: $selectedDate,
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)

                Spacer()

                quickButton("Now") { selectedDate = Self.roundToNearestQuarter(Date()) }
                quickButton("+1h") { adjust(hours: 1) }
                quickButton("+2h") { adjust(hours: 2) }
            }

            HStack(spacing: 8) {
                quickButton("Tomorrow 9 AM") { jumpTo(hour: 9, dayOffset: 1) }
                quickButton("Tomorrow 2 PM") { jumpTo(hour: 14, dayOffset: 1) }
                quickButton("Friday 10 AM") { jumpToNextWeekday(2, hour: 10) }
                Spacer()
            }
            .font(.caption)
        }
    }

    private var results: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(Array(allClocks.enumerated()), id: \.element.id) { index, clock in
                    MeetingPlannerRow(
                        clock: clock,
                        moment: selectedDate,
                        isLocal: index == 0
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                copyAsText()
            } label: {
                Label("Copy as text", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text(legendText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var legendText: String {
        "● working hours   ● awake   ● late / early"
    }

    // MARK: - Helpers

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func adjust(hours: Int) {
        selectedDate = Calendar.current.date(byAdding: .hour, value: hours, to: selectedDate) ?? selectedDate
    }

    private func jumpTo(hour: Int, dayOffset: Int) {
        var cal = Calendar.current
        cal.timeZone = .current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 1) + dayOffset
        comps.hour = hour
        comps.minute = 0
        if let d = cal.date(from: comps) {
            selectedDate = d
        }
    }

    /// Jump to the next occurrence of `weekday` (1=Sun … 7=Sat) at `hour`.
    private func jumpToNextWeekday(_ weekday: Int, hour: Int) {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = 0
        if let d = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) {
            selectedDate = d
        }
    }

    private static func roundToNearestQuarter(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        var rounded = comps
        let minute = comps.minute ?? 0
        rounded.minute = (minute / 15) * 15
        return cal.date(from: rounded) ?? date
    }

    private func copyAsText() {
        let lines = allClocks.map { clock -> String in
            let tz = clock.timeZone
            let df = DateFormatter()
            df.locale = .current
            df.timeZone = tz
            df.dateFormat = "EEE, MMM d · HH:mm"
            return "\(clock.displayName.padded(to: 18))  \(df.string(from: selectedDate))"
        }
        let payload = lines.joined(separator: "\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(payload, forType: .string)
    }
}

private struct MeetingPlannerRow: View {
    let clock: WorldClock
    let moment: Date
    let isLocal: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(zoneColor.opacity(0.85))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if isLocal {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tint)
                    }
                    Text(clock.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(dayLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(timeString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(zoneLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(zoneColor)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(zoneColor.opacity(0.08))
        )
    }

    // MARK: - Computed

    private var localHour: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = clock.timeZone
        return cal.component(.hour, from: moment)
    }

    private var zoneColor: Color {
        switch localHour {
        case 9..<18:  return .green
        case 7..<22:  return .orange
        default:      return .red
        }
    }

    private var zoneLabel: String {
        switch localHour {
        case 9..<18:  return "Working hours"
        case 7..<9:   return "Early"
        case 18..<22: return "Evening"
        default:      return "Sleeping"
        }
    }

    private var timeString: String {
        TimeFormatting.timeString(for: moment, in: clock.timeZone)
    }

    private var dayLabel: String {
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        var remoteCal = Calendar(identifier: .gregorian)
        remoteCal.timeZone = clock.timeZone

        let localComps = localCal.dateComponents([.year, .month, .day], from: moment)
        let remoteComps = remoteCal.dateComponents([.year, .month, .day], from: moment)

        var neutral = Calendar(identifier: .gregorian)
        neutral.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard let l = neutral.date(from: localComps),
              let r = neutral.date(from: remoteComps) else {
            return ""
        }

        let diff = neutral.dateComponents([.day], from: l, to: r).day ?? 0
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.timeZone = clock.timeZone
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        let dateLabel = weekdayFormatter.string(from: moment)

        switch diff {
        case 0:  return "Same day · \(dateLabel)"
        case 1:  return "+1 day · \(dateLabel)"
        case -1: return "−1 day · \(dateLabel)"
        default: return dateLabel
        }
    }
}

private extension String {
    func padded(to length: Int) -> String {
        if count >= length { return self }
        return self + String(repeating: " ", count: length - count)
    }
}
