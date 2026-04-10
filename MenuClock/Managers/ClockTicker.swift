import Foundation
import Combine

/// Publishes the current time, updated at each minute boundary.
final class ClockTicker: ObservableObject {
    static let shared = ClockTicker()

    @Published var now: Date = Date()

    private var timer: Timer?

    private init() {
        scheduleAlignedStart()
    }

    private func scheduleAlignedStart() {
        now = Date()
        let calendar = Calendar.current
        let next = calendar.nextDate(
            after: Date(),
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60)

        let delay = max(0.1, next.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.now = Date()
            let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
                self?.now = Date()
            }
            self.timer = t
            RunLoop.main.add(t, forMode: .common)
        }
    }
}
