import XCTest

final class ZoneStoreTests: XCTestCase {

    /// A fresh, isolated UserDefaults suite per test so nothing leaks between
    /// runs or touches the real App Group.
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.\(name).\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func makeStore(_ defaults: UserDefaults) -> ZoneStore {
        ZoneStore(defaults: defaults, reloadsWidgets: false)
    }

    func testStartsEmptyAndNotOnboarded() {
        let store = makeStore(makeDefaults())
        XCTAssertTrue(store.zones.isEmpty)
        XCTAssertFalse(store.didCompleteOnboarding)
        XCTAssertNil(store.referenceZone)
    }

    func testFinishOnboardingSetsHomeAndReference() {
        let store = makeStore(makeDefaults())
        store.finishOnboarding(
            homeIdentifier: "Africa/Lagos",
            otherIdentifiers: ["America/Los_Angeles", "America/New_York"],
            referenceIdentifier: "America/Los_Angeles",
            hourFormat: .twelveHour
        )
        XCTAssertEqual(store.zones.count, 3)
        XCTAssertEqual(store.homeZone?.tzIdentifier, "Africa/Lagos")
        XCTAssertEqual(store.referenceZone?.tzIdentifier, "America/Los_Angeles")
        XCTAssertTrue(store.didCompleteOnboarding)
        // Home is pinned first in the display order.
        XCTAssertEqual(store.displayZones.first?.tzIdentifier, "Africa/Lagos")
    }

    func testPersistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = makeStore(defaults)
        first.finishOnboarding(
            homeIdentifier: "Africa/Lagos",
            otherIdentifiers: ["Asia/Tokyo"],
            referenceIdentifier: nil,
            hourFormat: .twentyFourHour
        )
        // A new instance reading the same suite must see the same data.
        let second = makeStore(defaults)
        XCTAssertEqual(second.zones.count, 2)
        XCTAssertEqual(second.homeZone?.tzIdentifier, "Africa/Lagos")
        XCTAssertEqual(second.hourFormat, .twentyFourHour)
        XCTAssertTrue(second.didCompleteOnboarding)
    }

    func testAddAndRemoveZone() {
        let store = makeStore(makeDefaults())
        let z = store.addZone("Europe/London")
        XCTAssertEqual(store.zones.count, 1)
        XCTAssertEqual(store.referenceZone?.id, z.id) // first add becomes reference
        store.removeZone(z)
        XCTAssertTrue(store.zones.isEmpty)
        XCTAssertNil(store.referenceZone)
    }

    func testRemovingReferenceReassigns() {
        let store = makeStore(makeDefaults())
        store.finishOnboarding(
            homeIdentifier: "Africa/Lagos",
            otherIdentifiers: ["America/New_York"],
            referenceIdentifier: "America/New_York",
            hourFormat: .twelveHour
        )
        let ref = store.referenceZone!
        store.removeZone(ref)
        // Reference falls back to home.
        XCTAssertEqual(store.referenceZone?.tzIdentifier, "Africa/Lagos")
    }

    func testRenameFallsBackToCityWhenBlank() {
        let store = makeStore(makeDefaults())
        let z = store.addZone("America/Los_Angeles", displayName: "Work")
        store.rename(z, to: "   ")
        XCTAssertEqual(store.zones.first?.displayName, "Los Angeles")
    }

    func testLoadSnapshotMatchesWrittenState() {
        let defaults = makeDefaults()
        let store = makeStore(defaults)
        store.addZone("Asia/Singapore")
        let snapshot = ZoneStore.loadSnapshot(defaults: defaults)
        XCTAssertEqual(snapshot.zones.first?.tzIdentifier, "Asia/Singapore")
    }
}
