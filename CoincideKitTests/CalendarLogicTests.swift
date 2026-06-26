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
}
