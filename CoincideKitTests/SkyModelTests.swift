import XCTest

final class SkyModelTests: XCTestCase {

    private func date(hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: hour, minute: minute))!
    }

    private let utc = TimeZone(identifier: "UTC")!

    // MARK: - dayFraction

    func testDayFractionMidnightIsZero() {
        XCTAssertEqual(SkyModel.dayFraction(of: date(hour: 0, tz: utc), in: utc), 0, accuracy: 0.0001)
    }

    func testDayFractionNoonIsHalf() {
        XCTAssertEqual(SkyModel.dayFraction(of: date(hour: 12, tz: utc), in: utc), 0.5, accuracy: 0.0001)
    }

    func testDayFractionRespectsZone() {
        // 12:00 UTC is 05:00 in Los Angeles (UTC-7 in June) → fraction 5/24.
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let f = SkyModel.dayFraction(of: date(hour: 12, tz: utc), in: la)
        XCTAssertEqual(f, 5.0 / 24.0, accuracy: 0.0001)
    }

    // MARK: - isDaytime

    func testIsDaytimeBoundaries() {
        XCTAssertFalse(SkyModel.isDaytime(5.0 / 24.0))  // 05:00 — still night
        XCTAssertTrue(SkyModel.isDaytime(6.0 / 24.0))   // 06:00 — sunrise
        XCTAssertTrue(SkyModel.isDaytime(12.0 / 24.0))  // noon
        XCTAssertFalse(SkyModel.isDaytime(19.0 / 24.0)) // 19:00 — sunset (exclusive)
        XCTAssertFalse(SkyModel.isDaytime(23.0 / 24.0)) // late night
    }

    // MARK: - celestialArcPosition

    func testArcRisesAtSunriseAndSetsAtSunset() {
        let sunrise = SkyModel.celestialArcPosition(SkyModel.sunrise)
        let sunset = SkyModel.celestialArcPosition(SkyModel.sunset - 0.0001)
        XCTAssertEqual(sunrise.x, 0, accuracy: 0.01)   // enters at the left horizon
        XCTAssertEqual(sunrise.y, 1, accuracy: 0.01)
        XCTAssertEqual(sunset.x, 1, accuracy: 0.02)    // exits at the right horizon
        XCTAssertEqual(sunset.y, 1, accuracy: 0.02)
    }

    func testArcPeaksAtSolarNoon() {
        // Midpoint of the daytime window is highest (smallest y).
        let noon = SkyModel.celestialArcPosition((SkyModel.sunrise + SkyModel.sunset) / 2)
        XCTAssertEqual(noon.x, 0.5, accuracy: 0.02)
        XCTAssertEqual(noon.y, 0, accuracy: 0.02)
    }

    // MARK: - skyStops

    func testSkyStopsReturnDistinctDayAndNightColors() {
        let night = SkyModel.skyStops(0)      // midnight
        let day = SkyModel.skyStops(0.5)      // noon
        XCTAssertNotEqual(night.top, day.top)
        XCTAssertNotEqual(night.bottom, day.bottom)
        // Daytime sky reads lighter/bluer at the top than deep night.
        XCTAssertGreaterThan(day.bottom.b, night.top.b)
    }

    func testSkyStopsWrapAroundIsContinuous() {
        // Just before midnight and at midnight should be nearly identical.
        let before = SkyModel.skyStops(0.999)
        let at = SkyModel.skyStops(0)
        XCTAssertEqual(before.top.r, at.top.r, accuracy: 0.05)
        XCTAssertEqual(before.top.b, at.top.b, accuracy: 0.05)
    }

    func testSkyStopsClampFractionsOutsideUnitRange() {
        // 1.5 wraps to 0.5 → same as noon.
        let wrapped = SkyModel.skyStops(1.5)
        let noon = SkyModel.skyStops(0.5)
        XCTAssertEqual(wrapped.top, noon.top)
    }
}
