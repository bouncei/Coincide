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

    // MARK: - Meeting link

    func testHangoutLinkPreferredOverEverything() {
        let e = decode("""
        {"id":"a","summary":"Sync","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"},
         "htmlLink":"https://calendar.google.com/event?eid=1",
         "hangoutLink":"https://meet.google.com/abc-defg-hij",
         "location":"https://zoom.us/j/999",
         "conferenceData":{"entryPoints":[{"entryPointType":"video","uri":"https://meet.google.com/zzz"}]}}
        """)
        XCTAssertEqual(GoogleEventMapper.map(e)?.url?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testConferenceVideoEntryPointUsedWhenNoHangout() {
        let e = decode("""
        {"id":"b","summary":"Sync","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"},
         "htmlLink":"https://calendar.google.com/event?eid=2",
         "conferenceData":{"entryPoints":[
           {"entryPointType":"phone","uri":"tel:+1-555"},
           {"entryPointType":"video","uri":"https://zoom.us/j/123"}]}}
        """)
        XCTAssertEqual(GoogleEventMapper.map(e)?.url?.absoluteString, "https://zoom.us/j/123")
    }

    func testURLInLocationUsedWhenNoConference() {
        let e = decode("""
        {"id":"c","summary":"Sync","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"},
         "htmlLink":"https://calendar.google.com/event?eid=3",
         "location":"Join here https://zoom.us/j/456 or call in"}
        """)
        XCTAssertEqual(GoogleEventMapper.map(e)?.url?.absoluteString, "https://zoom.us/j/456")
    }

    func testHtmlLinkFallbackWhenNoMeetingLink() {
        let e = decode("""
        {"id":"d","summary":"Sync","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"},
         "htmlLink":"https://calendar.google.com/event?eid=4",
         "location":"Conference Room B"}
        """)
        XCTAssertEqual(GoogleEventMapper.map(e)?.url?.absoluteString, "https://calendar.google.com/event?eid=4")
    }

    func testNoLinkWhenNothingAvailable() {
        let e = decode("""
        {"id":"e","summary":"Sync","status":"confirmed",
         "start":{"dateTime":"2026-06-26T15:00:00Z"},"end":{"dateTime":"2026-06-26T15:30:00Z"},
         "location":"Conference Room B"}
        """)
        XCTAssertNil(GoogleEventMapper.map(e)?.url)
    }
}
