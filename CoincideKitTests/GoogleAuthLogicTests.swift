import XCTest

final class GoogleAuthLogicTests: XCTestCase {

    func testNeedsRefreshWhenNoExpiry() {
        XCTAssertTrue(GoogleAuthLogic.needsRefresh(expiry: nil, now: Date(), skew: 60))
    }

    func testNeedsRefreshWithinSkew() {
        let now = Date()
        XCTAssertTrue(GoogleAuthLogic.needsRefresh(expiry: now.addingTimeInterval(30), now: now, skew: 60))
        XCTAssertFalse(GoogleAuthLogic.needsRefresh(expiry: now.addingTimeInterval(600), now: now, skew: 60))
    }

    func testPKCEChallengeMatchesRFC7636Vector() {
        // RFC 7636 Appendix B test vector.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = GoogleAuthLogic.pkceChallenge(verifier: verifier)
        XCTAssertEqual(challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testMergeSortedConcatenatesAndOrders() {
        let a = [
            CalendarEventInfo(id: "a2", title: "a2", start: d(20), end: d(21), isAllDay: false, calendarColorHex: nil, location: nil)
        ]
        let b = [
            CalendarEventInfo(id: "b1", title: "b1", start: d(9), end: d(10), isAllDay: false, calendarColorHex: nil, location: nil),
            CalendarEventInfo(id: "b2", title: "b2", start: d(14), end: d(15), isAllDay: false, calendarColorHex: nil, location: nil)
        ]
        let merged = CalendarLogic.mergeSorted([a, b])
        XCTAssertEqual(merged.map(\.id), ["b1", "b2", "a2"])
    }

    private func d(_ hour: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 26; c.hour = hour
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }
}
