import XCTest

final class CalendarLogicTests: XCTestCase {

    private func d(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    private func ev(_ id: String, _ start: String, _ end: String, allDay: Bool = false) -> CalendarEventInfo {
        CalendarEventInfo(id: id, title: id, start: d(start), end: d(end),
                          isAllDay: allDay, calendarColorHex: nil, location: nil)
    }

    func testUpcomingExcludesPastAndAllDaySortedByStart() {
        let now = d("2026-06-26T14:00:00Z")
        let events = [
            ev("past", "2026-06-26T12:00:00Z", "2026-06-26T12:30:00Z"),
            ev("ongoing", "2026-06-26T13:30:00Z", "2026-06-26T14:30:00Z"),
            ev("later", "2026-06-26T16:00:00Z", "2026-06-26T16:30:00Z"),
            ev("soon", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z"),
            ev("allday", "2026-06-26T00:00:00Z", "2026-06-27T00:00:00Z", allDay: true),
        ]
        let up = CalendarLogic.upcoming(in: events, now: now)
        XCTAssertEqual(up.map(\.id), ["ongoing", "soon", "later"])
    }

    func testNextStartingPicksEarliestNotYetStarted() {
        let now = d("2026-06-26T14:00:00Z")
        let events = [
            ev("ongoing", "2026-06-26T13:30:00Z", "2026-06-26T14:30:00Z"),
            ev("later", "2026-06-26T16:00:00Z", "2026-06-26T16:30:00Z"),
            ev("soon", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z"),
        ]
        XCTAssertEqual(CalendarLogic.nextStarting(in: events, now: now)?.id, "soon")
    }

    func testMinutesUntilStart() {
        let now = d("2026-06-26T14:45:00Z")
        let e = ev("x", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        XCTAssertEqual(CalendarLogic.minutesUntilStart(e, now: now), 15)
    }

    func testIsImminentWithinThreshold() {
        let now = d("2026-06-26T14:45:00Z")
        let near = ev("near", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        let far = ev("far", "2026-06-26T15:40:00Z", "2026-06-26T16:00:00Z")
        XCTAssertTrue(CalendarLogic.isImminent(near, now: now, withinMinutes: 30))
        XCTAssertFalse(CalendarLogic.isImminent(far, now: now, withinMinutes: 30))
    }

    func testZoneLinesComputeTimeAndPhasePerZone() {
        // 2026-06-26T11:00:00Z -> Lagos 12:00 (day), New York 07:00 (morning).
        let event = ev("standup", "2026-06-26T11:00:00Z", "2026-06-26T11:30:00Z")
        let zones = [
            SavedZone(tzIdentifier: "Africa/Lagos"),
            SavedZone(tzIdentifier: "America/New_York"),
        ]
        let lines = CalendarLogic.zoneLines(for: event, zones: zones, format: .twentyFourHour)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].city, "Lagos")
        XCTAssertEqual(lines[0].time, "12:00")
        XCTAssertEqual(lines[0].phaseSymbol, "sun.max.fill")
        XCTAssertEqual(lines[1].city, "New York")
        XCTAssertEqual(lines[1].time, "07:00")
        XCTAssertEqual(lines[1].phaseSymbol, "sunrise.fill")
    }

    func testFractionClampsToDayWindow() {
        let dayStart = d("2026-06-26T00:00:00Z")
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-26T12:00:00Z"), dayStart: dayStart), 0.5, accuracy: 0.001)
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-25T20:00:00Z"), dayStart: dayStart), 0.0, accuracy: 0.001)
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-27T06:00:00Z"), dayStart: dayStart), 1.0, accuracy: 0.001)
    }

    func testTimelineBlocksClampToWindowAndSkipOutside() {
        let dayStart = d("2026-06-26T00:00:00Z")
        let events = [
            ev("morning", "2026-06-26T09:00:00Z", "2026-06-26T10:00:00Z"),     // inside
            ev("spillover", "2026-06-26T23:00:00Z", "2026-06-27T02:00:00Z"),   // clamps to 1.0 end
            ev("yesterday", "2026-06-25T08:00:00Z", "2026-06-25T09:00:00Z"),   // outside -> skipped
            ev("allday", "2026-06-26T00:00:00Z", "2026-06-27T00:00:00Z", allDay: true), // skipped
        ]
        let blocks = CalendarLogic.timelineBlocks(for: events, dayStart: dayStart)
        XCTAssertEqual(blocks.map(\.id), ["morning", "spillover"])
        XCTAssertEqual(blocks[0].startFraction, 9.0/24.0, accuracy: 0.001)
        XCTAssertEqual(blocks[1].endFraction, 1.0, accuracy: 0.001)
    }

    func testIsImminentZeroThresholdOnlyExactStart() {
        let now = d("2026-06-26T15:00:00Z")
        let atNow = ev("now", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        let soon = ev("soon", "2026-06-26T15:01:00Z", "2026-06-26T15:30:00Z")
        XCTAssertTrue(CalendarLogic.isImminent(atNow, now: now, withinMinutes: 0))
        XCTAssertFalse(CalendarLogic.isImminent(soon, now: now, withinMinutes: 0))
    }

    func testNextStartingIncludesEventStartingExactlyNow() {
        let now = d("2026-06-26T15:00:00Z")
        let atNow = ev("now", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        XCTAssertEqual(CalendarLogic.nextStarting(in: [atNow], now: now)?.id, "now")
    }
}
