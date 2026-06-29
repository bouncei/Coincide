import XCTest

final class GoogleEventMapperTests: XCTestCase {

    private func decode(_ json: String) -> GoogleAPIEvent {
        try! JSONDecoder().decode(GoogleAPIEvent.self, from: Data(json.utf8))
    }

    func testTimedEventMaps() {
        let e = decode("""
        {"id":"abc","summary":"Standup","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},
         "end":{"dateTime":"2026-06-26T15:30:00Z"},
         "colorId":"11","location":"Zoom"}
        """)
        let info = GoogleEventMapper.map(e)
        XCTAssertEqual(info?.id, "abc")
        XCTAssertEqual(info?.title, "Standup")
        XCTAssertEqual(info?.isAllDay, false)
        XCTAssertEqual(info?.calendarColorHex, "#DC2127")
        XCTAssertEqual(info?.location, "Zoom")
        XCTAssertEqual(info?.start, ISO8601DateFormatter().date(from: "2026-06-26T15:00:00Z"))
    }

    func testAllDayEventMaps() {
        let e = decode("""
        {"id":"d1","summary":"Holiday","status":"confirmed",
         "start":{"date":"2026-06-26"},"end":{"date":"2026-06-27"}}
        """)
        let info = GoogleEventMapper.map(e)
        XCTAssertEqual(info?.isAllDay, true)
        XCTAssertEqual(info?.title, "Holiday")
        XCTAssertNotNil(info?.start)
    }

    func testCancelledEventIsSkipped() {
        let e = decode("""
        {"id":"x","summary":"Gone","status":"cancelled",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"}}
        """)
        XCTAssertNil(GoogleEventMapper.map(e))
    }

    func testEmptyTitleFallsBack() {
        let e = decode("""
        {"id":"y","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"}}
        """)
        XCTAssertEqual(GoogleEventMapper.map(e)?.title, "(No title)")
    }

    func testMissingTimesSkipped() {
        let e = decode("""
        {"id":"z","summary":"Broken","status":"confirmed"}
        """)
        XCTAssertNil(GoogleEventMapper.map(e))
    }
}
