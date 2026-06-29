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

    struct EventZoneLine: Hashable {
        let flag: String
        let city: String
        let time: String
        let phaseSymbol: String
    }

    static func zoneLines(for event: CalendarEventInfo,
                          zones: [SavedZone],
                          format: HourFormat) -> [EventZoneLine] {
        zones.map { zone in
            EventZoneLine(
                flag: zone.flag,
                city: zone.cityName,
                time: TimeFormatting.time(in: zone.timeZone, at: event.start, format: format),
                phaseSymbol: DayPhase.current(in: zone.timeZone, at: event.start).symbol
            )
        }
    }

    struct TimelineBlock: Identifiable, Hashable {
        let event: CalendarEventInfo
        let startFraction: Double
        let endFraction: Double
        var id: String { event.id }
    }

    static func fraction(of date: Date, dayStart: Date) -> Double {
        let f = date.timeIntervalSince(dayStart) / 86_400
        return min(1, max(0, f))
    }

    static func timelineBlocks(for events: [CalendarEventInfo], dayStart: Date) -> [TimelineBlock] {
        let dayEnd = dayStart.addingTimeInterval(86_400)
        return events
            .filter { !$0.isAllDay && $0.end > dayStart && $0.start < dayEnd }
            .sorted { $0.start < $1.start }
            .map { event in
                let s = fraction(of: event.start, dayStart: dayStart)
                let e = max(fraction(of: event.end, dayStart: dayStart), s + 0.012) // min visible width
                return TimelineBlock(event: event, startFraction: s, endFraction: min(1, e))
            }
    }

    /// Concatenate event lists from multiple sources and sort by start.
    static func mergeSorted(_ lists: [[CalendarEventInfo]]) -> [CalendarEventInfo] {
        lists.flatMap { $0 }.sorted { $0.start < $1.start }
    }
}
