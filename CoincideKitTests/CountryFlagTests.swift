import XCTest

final class CountryFlagTests: XCTestCase {

    func testKnownZonesMapToCountryCodes() {
        XCTAssertEqual(TimezoneCountries.codeByZone["Africa/Lagos"], "NG")
        XCTAssertEqual(TimezoneCountries.codeByZone["America/Los_Angeles"], "US")
        XCTAssertEqual(TimezoneCountries.codeByZone["Europe/London"], "GB")
        XCTAssertEqual(TimezoneCountries.codeByZone["Asia/Kolkata"], "IN")
    }

    func testFlagEmojiFromCountryCode() {
        XCTAssertEqual(SavedZone.flag(for: "NG"), "🇳🇬")
        XCTAssertEqual(SavedZone.flag(for: "US"), "🇺🇸")
        XCTAssertEqual(SavedZone.flag(for: "gb"), "🇬🇧") // case-insensitive
    }

    func testFlagFallsBackToGlobe() {
        XCTAssertEqual(SavedZone.flag(for: nil), "🌐")
        XCTAssertEqual(SavedZone.flag(for: "XYZ"), "🌐")   // wrong length
        XCTAssertEqual(SavedZone.flag(for: "12"), "🌐")    // non-letters
    }

    func testSavedZoneSurfacesFlagAndCountry() {
        let lagos = SavedZone(tzIdentifier: "Africa/Lagos")
        XCTAssertEqual(lagos.flag, "🇳🇬")
        XCTAssertEqual(lagos.countryName, "Nigeria")

        // Region-less zone gets a globe and no country.
        let utc = SavedZone(tzIdentifier: "UTC")
        XCTAssertEqual(utc.flag, "🌐")
        XCTAssertNil(utc.countryName)
    }
}
