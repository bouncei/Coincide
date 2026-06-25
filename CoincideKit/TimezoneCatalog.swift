import Foundation

/// One selectable entry in the timezone picker.
struct CatalogZone: Identifiable, Hashable {
    let id: String          // IANA identifier
    var identifier: String { id }
    var city: String { SavedZone.cityName(for: id) }
    var region: String { SavedZone.region(for: id) }
    var countryCode: String? { TimezoneCountries.codeByZone[id] }
    var countryName: String? {
        guard let code = countryCode else { return nil }
        return Locale.current.localizedString(forRegionCode: code)
    }
    var flag: String { SavedZone.flag(for: countryCode) }
}

/// The full IANA catalog plus a curated "Common" shortlist. The picker is not
/// limited to any subset — every system timezone is selectable, and the user
/// can add as many as they like.
enum TimezoneCatalog {
    /// A small, globally useful shortlist surfaced first in the picker.
    static let commonIdentifiers: [String] = [
        "America/Los_Angeles",
        "America/Denver",
        "America/Chicago",
        "America/New_York",
        "America/Sao_Paulo",
        "UTC",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Africa/Lagos",
        "Africa/Johannesburg",
        "Asia/Dubai",
        "Asia/Kolkata",
        "Asia/Singapore",
        "Asia/Shanghai",
        "Asia/Tokyo",
        "Australia/Sydney"
    ]

    static let common: [CatalogZone] = commonIdentifiers
        .filter { TimeZone(identifier: $0) != nil }
        .map { CatalogZone(id: $0) }

    /// Every known timezone, sorted by identifier.
    static let all: [CatalogZone] = TimeZone.knownTimeZoneIdentifiers
        .sorted()
        .map { CatalogZone(id: $0) }

    /// Filter by city, identifier, or abbreviation. Empty query returns all.
    static func search(_ query: String) -> [CatalogZone] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { zone in
            if zone.city.lowercased().contains(q) { return true }
            if zone.id.lowercased().contains(q) { return true }
            if let abbr = TimeZone(identifier: zone.id)?.abbreviation()?.lowercased(),
               abbr.contains(q) { return true }
            return false
        }
    }

    /// All zones grouped by region/continent for a sectioned picker.
    static var grouped: [(region: String, zones: [CatalogZone])] {
        Dictionary(grouping: all, by: { $0.region })
            .map { (region: $0.key, zones: $0.value.sorted { $0.city < $1.city }) }
            .sorted { $0.region < $1.region }
    }
}
