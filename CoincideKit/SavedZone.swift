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

    static func cityName(for tzIdentifier: String) -> String {
        let last = tzIdentifier.split(separator: "/").last.map(String.init) ?? tzIdentifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Region/continent prefix, e.g. "America".
    static func region(for tzIdentifier: String) -> String {
        tzIdentifier.split(separator: "/").first.map(String.init) ?? "Other"
    }
}
