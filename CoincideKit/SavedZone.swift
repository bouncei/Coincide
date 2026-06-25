import Foundation

/// A timezone the user has chosen to track. Persisted (Codable) and shared
/// between the app and the widget via the App Group store.
struct SavedZone: Codable, Identifiable, Hashable {
    var id: UUID
    /// IANA identifier, e.g. "America/Los_Angeles".
    var tzIdentifier: String
    /// User-editable label, e.g. "Work — PST". Defaults to the city name.
    var displayName: String

    init(id: UUID = UUID(), tzIdentifier: String, displayName: String? = nil) {
        self.id = id
        self.tzIdentifier = tzIdentifier
        self.displayName = displayName ?? SavedZone.cityName(for: tzIdentifier)
    }

    /// The resolved `TimeZone`, falling back to the current zone if the
    /// identifier is somehow unknown (defensive — identifiers come from the
    /// system catalog).
    var timeZone: TimeZone {
        TimeZone(identifier: tzIdentifier) ?? .current
    }

    /// Human city name derived from the identifier, e.g. "Los Angeles".
    var cityName: String {
        SavedZone.cityName(for: tzIdentifier)
    }

    /// ISO 3166-1 alpha-2 country code for this zone, e.g. "US", "NG".
    var countryCode: String? {
        TimezoneCountries.codeByZone[tzIdentifier]
    }

    /// Localized country name, e.g. "Nigeria". Nil for region-less zones (UTC).
    var countryName: String? {
        guard let code = countryCode else { return nil }
        return Locale.current.localizedString(forRegionCode: code)
    }

    /// Flag emoji for the zone's country, or a globe for region-less zones.
    var flag: String {
        SavedZone.flag(for: countryCode)
    }

    static func cityName(for tzIdentifier: String) -> String {
        let last = tzIdentifier.split(separator: "/").last.map(String.init) ?? tzIdentifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Region/continent prefix, e.g. "America".
    static func region(for tzIdentifier: String) -> String {
        tzIdentifier.split(separator: "/").first.map(String.init) ?? "Other"
    }

    /// Builds a flag emoji from an ISO country code using regional-indicator
    /// scalars. Falls back to a globe when there's no (valid) country.
    static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "🌐" }
        let base: UInt32 = 0x1F1E6 - 0x41 // regional indicator "A" minus ASCII "A"
        var scalars = String.UnicodeScalarView()
        for ch in code.uppercased().unicodeScalars {
            guard ch.value >= 0x41, ch.value <= 0x5A,
                  let scalar = Unicode.Scalar(base + ch.value) else { return "🌐" }
            scalars.append(scalar)
        }
        return String(scalars)
    }
}
