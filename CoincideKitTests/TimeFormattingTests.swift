import XCTest

final class TimeFormattingTests: XCTestCase {

    private func tz(_ id: String) -> TimeZone {
        guard let z = TimeZone(identifier: id) else {
            fatalError("unknown test timezone \(id)")
        }
        return z
    }

    // A fixed instant: 2026-06-22 20:00:00 UTC (June => US DST in effect).
    private var june22_2000UTC: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 22
        c.hour = 20; c.minute = 0; c.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz("UTC")
        return cal.date(from: c)!
    }

    func testTwelveHourFormatting() {
        // 20:00 UTC -> Lagos is GMT+1 (no DST) -> 21:00 -> "9:00 PM".
        let s = TimeFormatting.time(in: tz("Africa/Lagos"), at: june22_2000UTC, format: .twelveHour)
        XCTAssertEqual(s, "9:00 PM")
    }

    func testTwentyFourHourFormatting() {
        let s = TimeFormatting.time(in: tz("Africa/Lagos"), at: june22_2000UTC, format: .twentyFourHour)
        XCTAssertEqual(s, "21:00")
    }

    func testLosAngelesSummerOffsetIsDST() {
        // June -> America/Los_Angeles observes PDT (GMT-7).
        let label = TimeFormatting.gmtOffsetLabel(for: tz("America/Los_Angeles"), at: june22_2000UTC)
        XCTAssertEqual(label, "GMT-7")
    }

    func testLagosOffsetNoMinutes() {
        let label = TimeFormatting.gmtOffsetLabel(for: tz("Africa/Lagos"), at: june22_2000UTC)
        XCTAssertEqual(label, "GMT+1")
    }

    func testIndiaHalfHourOffset() {
        // Asia/Kolkata is GMT+5:30 year round.
        let label = TimeFormatting.gmtOffsetLabel(for: tz("Asia/Kolkata"), at: june22_2000UTC)
        XCTAssertEqual(label, "GMT+5:30")
    }

    func testNewYorkSummerTime() {
        // 20:00 UTC -> New York EDT (GMT-4) -> 16:00 -> "4:00 PM".
        let s = TimeFormatting.time(in: tz("America/New_York"), at: june22_2000UTC, format: .twelveHour)
        XCTAssertEqual(s, "4:00 PM")
    }

    func testDayOffsetTomorrow() {
        // Late evening UTC where Sydney has already rolled to the next day.
        // 2026-06-22 20:00 UTC -> Sydney (GMT+10) is 2026-06-23 06:00 -> Tomorrow.
        let label = TimeFormatting.dayOffsetLabel(
            home: tz("Africa/Lagos"),      // 2026-06-22 21:00
            other: tz("Australia/Sydney"), // 2026-06-23 06:00
            at: june22_2000UTC
        )
        XCTAssertEqual(label, "Tomorrow")
    }

    func testDayOffsetYesterday() {
        // Build an instant just after midnight in Lagos so Los Angeles is the
        // previous day. 2026-06-22 00:30 UTC -> Lagos 01:30 (22nd),
        // LA is GMT-7 -> 2026-06-21 17:30 -> Yesterday.
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 22; c.hour = 0; c.minute = 30
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz("UTC")
        let date = cal.date(from: c)!
        let label = TimeFormatting.dayOffsetLabel(
            home: tz("Africa/Lagos"),
            other: tz("America/Los_Angeles"),
            at: date
        )
        XCTAssertEqual(label, "Yesterday")
    }

    func testSameDayHasNoLabel() {
        let label = TimeFormatting.dayOffsetLabel(
            home: tz("Africa/Lagos"),
            other: tz("Europe/London"),
            at: june22_2000UTC
        )
        XCTAssertNil(label)
    }
}
