import Foundation

/// Pure, unit-tested selection/formatting logic for calendar events. No EventKit.
enum CalendarLogic {

    /// Timed events still relevant (end in the future), sorted by start.
    static func upcoming(in events: [CalendarEventInfo], now: Date) -> [CalendarEventInfo] {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .sorted { $0.start < $1.start }
    }

    /// The earliest timed event that hasn't started yet.
    static func nextStarting(in events: [CalendarEventInfo], now: Date) -> CalendarEventInfo? {
        events
            .filter { !$0.isAllDay && $0.start >= now }
            .min { $0.start < $1.start }
    }

    static func minutesUntilStart(_ event: CalendarEventInfo, now: Date) -> Int {
        Int((event.start.timeIntervalSince(now) / 60).rounded(.down))
    }

    static func isImminent(_ event: CalendarEventInfo, now: Date, withinMinutes: Int) -> Bool {
        let m = minutesUntilStart(event, now: now)
        return m >= 0 && m <= withinMinutes
    }
}
