import Foundation

/// Publishes the current time once per minute, aligned to the minute boundary.
///
/// We deliberately avoid `TimelineView` inside the `MenuBarExtra`: on macOS a
/// `TimelineView` in the menu bar label drives the status-item button into an
/// infinite re-layout loop (`MenuBarExtraController.updateButton` →
/// `NSStatusItem _adjustLength`), pinning the main thread. A plain timer that
/// nudges an `@Published` value once a minute gives us a live clock with a
/// single, cheap re-render per minute and no loop.
final class MinuteClock: ObservableObject {
    @Published private(set) var now: Date = Date()

    private var timer: Timer?

    init() { start() }

    deinit { timer?.invalidate() }

    private func start() {
        now = Date()
        let calendar = Calendar.current
        let nextMinute = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60)

        let timer = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
