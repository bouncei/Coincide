import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The full persisted state, shared between the app and the widget.
struct StoreState: Codable {
    var zones: [SavedZone]
    var homeZoneID: UUID?
    var referenceZoneID: UUID?
    var hourFormat: HourFormat
    var didCompleteOnboarding: Bool

    static let empty = StoreState(
        zones: [],
        homeZoneID: nil,
        referenceZoneID: nil,
        hourFormat: .twelveHour,
        didCompleteOnboarding: false
    )
}

extension StoreState {
    var homeZone: SavedZone? { zones.first { $0.id == homeZoneID } }

    var referenceZone: SavedZone? {
        zones.first { $0.id == referenceZoneID } ?? homeZone ?? zones.first
    }

    var homeTimeZone: TimeZone { homeZone?.timeZone ?? .current }

    /// Home pinned first, then the remaining zones in their stored order.
    var displayZones: [SavedZone] {
        guard let home = homeZone else { return zones }
        return [home] + zones.filter { $0.id != home.id }
    }
}

/// Observable, App Group–backed store of the user's zones and preferences.
///
/// The app drives this object; the widget reads a static snapshot via
/// `loadSnapshot`. Persistence is a single JSON blob in the App Group's
/// `UserDefaults` suite so both processes always agree.
final class ZoneStore: ObservableObject {
    static let appGroupID = "group.dev.bouncei.coincide"
    static let stateKey = "state.v1"

    @Published private(set) var zones: [SavedZone]
    @Published private(set) var homeZoneID: UUID?
    @Published private(set) var referenceZoneID: UUID?
    @Published var hourFormat: HourFormat { didSet { persist() } }
    @Published private(set) var didCompleteOnboarding: Bool

    private let defaults: UserDefaults
    private let reloadsWidgets: Bool

    /// - Parameters:
    ///   - defaults: injectable for tests; defaults to the App Group suite.
    ///   - reloadsWidgets: disabled in tests so we don't touch WidgetKit.
    init(defaults: UserDefaults? = nil, reloadsWidgets: Bool = true) {
        self.defaults = defaults ?? UserDefaults(suiteName: ZoneStore.appGroupID) ?? .standard
        self.reloadsWidgets = reloadsWidgets
        let state = ZoneStore.load(from: self.defaults) ?? .empty
        self.zones = state.zones
        self.homeZoneID = state.homeZoneID
        self.referenceZoneID = state.referenceZoneID
        self.hourFormat = state.hourFormat
        self.didCompleteOnboarding = state.didCompleteOnboarding
    }

    // MARK: - Derived

    var homeZone: SavedZone? { zones.first { $0.id == homeZoneID } }

    /// The zone shown in the menu bar. Falls back to home, then first.
    var referenceZone: SavedZone? {
        zones.first { $0.id == referenceZoneID } ?? homeZone ?? zones.first
    }

    var homeTimeZone: TimeZone { homeZone?.timeZone ?? .current }

    /// Home pinned first, then the remaining zones in their stored order.
    var displayZones: [SavedZone] {
        guard let home = homeZone else { return zones }
        return [home] + zones.filter { $0.id != home.id }
    }

    func isHome(_ zone: SavedZone) -> Bool { zone.id == homeZoneID }
    func isReference(_ zone: SavedZone) -> Bool { referenceZone?.id == zone.id }

    // MARK: - Mutations

    @discardableResult
    func addZone(_ tzIdentifier: String, displayName: String? = nil) -> SavedZone {
        let zone = SavedZone(tzIdentifier: tzIdentifier, displayName: displayName)
        zones.append(zone)
        if referenceZoneID == nil { referenceZoneID = zone.id }
        persist()
        return zone
    }

    func removeZone(_ zone: SavedZone) {
        zones.removeAll { $0.id == zone.id }
        if homeZoneID == zone.id { homeZoneID = zones.first?.id }
        if referenceZoneID == zone.id { referenceZoneID = homeZoneID ?? zones.first?.id }
        persist()
    }

    func rename(_ zone: SavedZone, to name: String) {
        guard let idx = zones.firstIndex(where: { $0.id == zone.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        zones[idx].displayName = trimmed.isEmpty ? zones[idx].cityName : trimmed
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        zones.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    func moveUp(_ zone: SavedZone) {
        guard let i = zones.firstIndex(where: { $0.id == zone.id }), i > 0 else { return }
        zones.swapAt(i, i - 1)
        persist()
    }

    func moveDown(_ zone: SavedZone) {
        guard let i = zones.firstIndex(where: { $0.id == zone.id }), i < zones.count - 1 else { return }
        zones.swapAt(i, i + 1)
        persist()
    }

    func setHome(_ zone: SavedZone) {
        homeZoneID = zone.id
        persist()
    }

    func setReference(_ zone: SavedZone) {
        referenceZoneID = zone.id
        persist()
    }

    /// Used by onboarding to write the initial state in one shot.
    func finishOnboarding(homeIdentifier: String,
                          otherIdentifiers: [String],
                          referenceIdentifier: String?,
                          hourFormat: HourFormat) {
        var newZones: [SavedZone] = []
        let home = SavedZone(tzIdentifier: homeIdentifier)
        newZones.append(home)
        for id in otherIdentifiers where id != homeIdentifier {
            newZones.append(SavedZone(tzIdentifier: id))
        }
        self.zones = newZones
        self.homeZoneID = home.id
        let refID = referenceIdentifier
            .flatMap { ref in newZones.first { $0.tzIdentifier == ref }?.id }
        self.referenceZoneID = refID ?? home.id
        self.hourFormat = hourFormat   // triggers a persist via didSet
        self.didCompleteOnboarding = true
        persist()
    }

    func resetOnboarding() {
        didCompleteOnboarding = false
        persist()
    }

    // MARK: - Persistence

    private func snapshot() -> StoreState {
        StoreState(
            zones: zones,
            homeZoneID: homeZoneID,
            referenceZoneID: referenceZoneID,
            hourFormat: hourFormat,
            didCompleteOnboarding: didCompleteOnboarding
        )
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot()) {
            defaults.set(data, forKey: ZoneStore.stateKey)
        }
        #if canImport(WidgetKit)
        if reloadsWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    private static func load(from defaults: UserDefaults) -> StoreState? {
        guard let data = defaults.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(StoreState.self, from: data)
    }

    /// Read-only snapshot for the widget process.
    static func loadSnapshot(defaults: UserDefaults? = nil) -> StoreState {
        let d = defaults ?? UserDefaults(suiteName: appGroupID) ?? .standard
        return load(from: d) ?? .empty
    }
}
