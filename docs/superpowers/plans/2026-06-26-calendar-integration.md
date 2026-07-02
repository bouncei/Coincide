# Calendar Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add read-only Apple EventKit calendar context to Coincide — upcoming meetings in the popover and menu bar (shown across the user's tracked zones) and as blocks on the dashboard's day/night timeline.

**Architecture:** Pure, unit-tested logic lives in `CoincideKit` (`CalendarEventInfo` model + `CalendarLogic` functions). A thin `CalendarService` in the app target wraps `EKEventStore` (auth, fetch, map, publish) and is the only type touching EventKit. The existing popover, menu bar label, dashboard, and settings views consume it. Nothing is added to the widget.

**Tech Stack:** Swift 5 / SwiftUI, EventKit, XcodeGen, XCTest. No new third-party dependencies, no network.

## Global Constraints

- Deployment target: **macOS 14.0**. Use macOS 14 EventKit APIs (`requestFullAccessToEvents()`, `EKAuthorizationStatus.fullAccess`).
- **No network entitlement** — EventKit only. Add only the App Sandbox calendars entitlement.
- Reuse existing helpers: `TimeFormatting`, `DayPhase`, `SavedZone`, `MinuteClock`, `ZoneStore`. Do not duplicate time/day-night logic.
- **Never use `TimelineView` inside the `MenuBarExtra` subtree** (it caused a prior freeze) — drive per-minute updates from `MinuteClock`.
- Branch: all work on `feature/calendar-integration`.
- Pure logic goes in `CoincideKit`; EventKit stays in the app target; the widget is untouched.
- Build/test command (no signing): `xcodebuild ... CODE_SIGNING_ALLOWED=NO`. Regenerate the project with `xcodegen generate` after adding files (run `export PATH="/usr/local/bin:$PATH"` first so `xcodegen` resolves).

---

## File Structure

**Create:**
- `CoincideKit/CalendarEventInfo.swift` — the value model.
- `CoincideKit/CalendarLogic.swift` — pure functions (next/upcoming/imminent, zone lines, timeline blocks).
- `CoincideKitTests/CalendarLogicTests.swift` — unit tests for the above.
- `Coincide/Calendar/CalendarService.swift` — EventKit shim (`ObservableObject`).
- `Coincide/Calendar/EventRowView.swift` — popover "Up next" row (expandable per-zone).

**Modify:**
- `project.yml` — add the calendar usage-description Info.plist key to the app target.
- `Coincide/Coincide.entitlements` — add the calendars entitlement.
- `Coincide/CoincideApp.swift` — create + inject `CalendarService`.
- `Coincide/MenuBar/MenuBarLabelView.swift` — imminent-event display.
- `Coincide/MenuBar/PopoverView.swift` — "Up next" section.
- `Coincide/MainWindow/MainDashboardView.swift` — events lane.
- `Coincide/Settings/SettingsView.swift` — Calendar section.

---

### Task 1: `CalendarEventInfo` model + next/upcoming/imminent logic

**Files:**
- Create: `CoincideKit/CalendarEventInfo.swift`
- Create: `CoincideKit/CalendarLogic.swift`
- Test: `CoincideKitTests/CalendarLogicTests.swift`

**Interfaces:**
- Produces:
  - `struct CalendarEventInfo: Identifiable, Hashable { let id: String; let title: String; let start: Date; let end: Date; let isAllDay: Bool; let calendarColorHex: String?; let location: String? }`
  - `enum CalendarLogic` with:
    - `static func upcoming(in events: [CalendarEventInfo], now: Date) -> [CalendarEventInfo]` (timed events whose `end > now`, sorted by `start`)
    - `static func nextStarting(in events: [CalendarEventInfo], now: Date) -> CalendarEventInfo?` (earliest timed event with `start >= now`)
    - `static func minutesUntilStart(_ event: CalendarEventInfo, now: Date) -> Int`
    - `static func isImminent(_ event: CalendarEventInfo, now: Date, withinMinutes: Int) -> Bool`

- [ ] **Step 1: Write the failing test**

Create `CoincideKitTests/CalendarLogicTests.swift`:

```swift
import XCTest

final class CalendarLogicTests: XCTestCase {

    private func d(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    private func ev(_ id: String, _ start: String, _ end: String, allDay: Bool = false) -> CalendarEventInfo {
        CalendarEventInfo(id: id, title: id, start: d(start), end: d(end),
                          isAllDay: allDay, calendarColorHex: nil, location: nil)
    }

    func testUpcomingExcludesPastAndAllDaySortedByStart() {
        let now = d("2026-06-26T14:00:00Z")
        let events = [
            ev("past", "2026-06-26T12:00:00Z", "2026-06-26T12:30:00Z"),
            ev("ongoing", "2026-06-26T13:30:00Z", "2026-06-26T14:30:00Z"),
            ev("later", "2026-06-26T16:00:00Z", "2026-06-26T16:30:00Z"),
            ev("soon", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z"),
            ev("allday", "2026-06-26T00:00:00Z", "2026-06-27T00:00:00Z", allDay: true),
        ]
        let up = CalendarLogic.upcoming(in: events, now: now)
        XCTAssertEqual(up.map(\.id), ["ongoing", "soon", "later"])
    }

    func testNextStartingPicksEarliestNotYetStarted() {
        let now = d("2026-06-26T14:00:00Z")
        let events = [
            ev("ongoing", "2026-06-26T13:30:00Z", "2026-06-26T14:30:00Z"),
            ev("later", "2026-06-26T16:00:00Z", "2026-06-26T16:30:00Z"),
            ev("soon", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z"),
        ]
        XCTAssertEqual(CalendarLogic.nextStarting(in: events, now: now)?.id, "soon")
    }

    func testMinutesUntilStart() {
        let now = d("2026-06-26T14:45:00Z")
        let e = ev("x", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        XCTAssertEqual(CalendarLogic.minutesUntilStart(e, now: now), 15)
    }

    func testIsImminentWithinThreshold() {
        let now = d("2026-06-26T14:45:00Z")
        let near = ev("near", "2026-06-26T15:00:00Z", "2026-06-26T15:30:00Z")
        let far = ev("far", "2026-06-26T15:40:00Z", "2026-06-26T16:00:00Z")
        XCTAssertTrue(CalendarLogic.isImminent(near, now: now, withinMinutes: 30))
        XCTAssertFalse(CalendarLogic.isImminent(far, now: now, withinMinutes: 30))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`
Expected: FAIL — `cannot find 'CalendarEventInfo' in scope` / `CalendarLogic`.

- [ ] **Step 3: Write minimal implementation**

Create `CoincideKit/CalendarEventInfo.swift`:

```swift
import Foundation

/// A read-only snapshot of a calendar event, mapped from EventKit's `EKEvent`
/// so that EventKit types never leak past `CalendarService`.
struct CalendarEventInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarColorHex: String?
    let location: String?
}
```

Create `CoincideKit/CalendarLogic.swift`:

```swift
import Foundation

/// Pure, unit-tested selection/formatting logic for calendar events. No EventKit.
enum CalendarLogic {

    /// Timed events still relevant (end in the future), sorted by start.
    static func upcoming(in events: [CalendarEventInfo], now: Date) -> [CalendarEventInfo] {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .sorted { $0.start < $1.start }
    }

    /// The earliest timed event that hasn't started yet.
    static func nextStarting(in events: [CalendarEventInfo], now: Date) -> CalendarEventInfo? {
        events
            .filter { !$0.isAllDay && $0.start >= now }
            .min { $0.start < $1.start }
    }

    static func minutesUntilStart(_ event: CalendarEventInfo, now: Date) -> Int {
        Int((event.start.timeIntervalSince(now) / 60).rounded(.down))
    }

    static func isImminent(_ event: CalendarEventInfo, now: Date, withinMinutes: Int) -> Bool {
        let m = minutesUntilStart(event, now: now)
        return m >= 0 && m <= withinMinutes
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — all `CalendarLogicTests` green; total executed count rises from 20 to 24.

- [ ] **Step 5: Commit**

```bash
cd /Users/joshuainyang/Documents/Coincide
git add CoincideKit/CalendarEventInfo.swift CoincideKit/CalendarLogic.swift CoincideKitTests/CalendarLogicTests.swift
git commit -m "feat(calendar): event model + next/upcoming/imminent logic"
```

---

### Task 2: Per-zone event lines

**Files:**
- Modify: `CoincideKit/CalendarLogic.swift`
- Test: `CoincideKitTests/CalendarLogicTests.swift`

**Interfaces:**
- Consumes: `SavedZone` (`.flag`, `.cityName`, `.timeZone`), `HourFormat`, `TimeFormatting.time`, `DayPhase.current`.
- Produces:
  - `struct EventZoneLine: Hashable { let flag: String; let city: String; let time: String; let phaseSymbol: String }`
  - `static func zoneLines(for event: CalendarEventInfo, zones: [SavedZone], format: HourFormat) -> [EventZoneLine]`

- [ ] **Step 1: Write the failing test**

Append to `CoincideKitTests/CalendarLogicTests.swift` (inside the class):

```swift
    func testZoneLinesComputeTimeAndPhasePerZone() {
        // 2026-06-26T11:00:00Z -> Lagos 12:00 (day), New York 07:00 (morning).
        let event = ev("standup", "2026-06-26T11:00:00Z", "2026-06-26T11:30:00Z")
        let zones = [
            SavedZone(tzIdentifier: "Africa/Lagos"),
            SavedZone(tzIdentifier: "America/New_York"),
        ]
        let lines = CalendarLogic.zoneLines(for: event, zones: zones, format: .twentyFourHour)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].city, "Lagos")
        XCTAssertEqual(lines[0].time, "12:00")
        XCTAssertEqual(lines[0].phaseSymbol, "sun.max.fill")
        XCTAssertEqual(lines[1].city, "New York")
        XCTAssertEqual(lines[1].time, "07:00")
        XCTAssertEqual(lines[1].phaseSymbol, "sunrise.fill")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: FAIL — `type 'CalendarLogic' has no member 'zoneLines'`.

- [ ] **Step 3: Write minimal implementation**

Append to `CoincideKit/CalendarLogic.swift` (inside `enum CalendarLogic`):

```swift
    struct EventZoneLine: Hashable {
        let flag: String
        let city: String
        let time: String
        let phaseSymbol: String
    }

    static func zoneLines(for event: CalendarEventInfo,
                          zones: [SavedZone],
                          format: HourFormat) -> [EventZoneLine] {
        zones.map { zone in
            EventZoneLine(
                flag: zone.flag,
                city: zone.cityName,
                time: TimeFormatting.time(in: zone.timeZone, at: event.start, format: format),
                phaseSymbol: DayPhase.current(in: zone.timeZone, at: event.start).symbol
            )
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — executed count 25.

- [ ] **Step 5: Commit**

```bash
git add CoincideKit/CalendarLogic.swift CoincideKitTests/CalendarLogicTests.swift
git commit -m "feat(calendar): per-zone event time lines"
```

---

### Task 3: Timeline blocks (dashboard overlay geometry)

**Files:**
- Modify: `CoincideKit/CalendarLogic.swift`
- Test: `CoincideKitTests/CalendarLogicTests.swift`

**Interfaces:**
- Produces:
  - `struct TimelineBlock: Identifiable, Hashable { let event: CalendarEventInfo; let startFraction: Double; let endFraction: Double; var id: String { event.id } }`
  - `static func fraction(of date: Date, dayStart: Date) -> Double` (clamped 0...1 over a 24h window)
  - `static func timelineBlocks(for events: [CalendarEventInfo], dayStart: Date) -> [TimelineBlock]` (timed events overlapping `[dayStart, dayStart+24h]`, clamped, min width enforced)

- [ ] **Step 1: Write the failing test**

Append to `CoincideKitTests/CalendarLogicTests.swift`:

```swift
    func testFractionClampsToDayWindow() {
        let dayStart = d("2026-06-26T00:00:00Z")
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-26T12:00:00Z"), dayStart: dayStart), 0.5, accuracy: 0.001)
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-25T20:00:00Z"), dayStart: dayStart), 0.0, accuracy: 0.001)
        XCTAssertEqual(CalendarLogic.fraction(of: d("2026-06-27T06:00:00Z"), dayStart: dayStart), 1.0, accuracy: 0.001)
    }

    func testTimelineBlocksClampToWindowAndSkipOutside() {
        let dayStart = d("2026-06-26T00:00:00Z")
        let events = [
            ev("morning", "2026-06-26T09:00:00Z", "2026-06-26T10:00:00Z"),     // inside
            ev("spillover", "2026-06-26T23:00:00Z", "2026-06-27T02:00:00Z"),   // clamps to 1.0 end
            ev("yesterday", "2026-06-25T08:00:00Z", "2026-06-25T09:00:00Z"),   // outside -> skipped
            ev("allday", "2026-06-26T00:00:00Z", "2026-06-27T00:00:00Z", allDay: true), // skipped
        ]
        let blocks = CalendarLogic.timelineBlocks(for: events, dayStart: dayStart)
        XCTAssertEqual(blocks.map(\.id), ["morning", "spillover"])
        XCTAssertEqual(blocks[0].startFraction, 9.0/24.0, accuracy: 0.001)
        XCTAssertEqual(blocks[1].endFraction, 1.0, accuracy: 0.001)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: FAIL — no member `fraction` / `timelineBlocks`.

- [ ] **Step 3: Write minimal implementation**

Append to `CoincideKit/CalendarLogic.swift` (inside `enum CalendarLogic`):

```swift
    struct TimelineBlock: Identifiable, Hashable {
        let event: CalendarEventInfo
        let startFraction: Double
        let endFraction: Double
        var id: String { event.id }
    }

    static func fraction(of date: Date, dayStart: Date) -> Double {
        let f = date.timeIntervalSince(dayStart) / 86_400
        return min(1, max(0, f))
    }

    static func timelineBlocks(for events: [CalendarEventInfo], dayStart: Date) -> [TimelineBlock] {
        let dayEnd = dayStart.addingTimeInterval(86_400)
        return events
            .filter { !$0.isAllDay && $0.end > dayStart && $0.start < dayEnd }
            .sorted { $0.start < $1.start }
            .map { event in
                let s = fraction(of: event.start, dayStart: dayStart)
                let e = max(fraction(of: event.end, dayStart: dayStart), s + 0.012) // min visible width
                return TimelineBlock(event: event, startFraction: s, endFraction: min(1, e))
            }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — executed count 27.

- [ ] **Step 5: Commit**

```bash
git add CoincideKit/CalendarLogic.swift CoincideKitTests/CalendarLogicTests.swift
git commit -m "feat(calendar): timeline block geometry for the dashboard overlay"
```

---

### Task 4: EventKit permission + `CalendarService` + app wiring

**Files:**
- Modify: `Coincide/Coincide.entitlements`
- Modify: `project.yml`
- Create: `Coincide/Calendar/CalendarService.swift`
- Modify: `Coincide/CoincideApp.swift`

**Interfaces:**
- Consumes: `CalendarEventInfo`.
- Produces: `@MainActor final class CalendarService: ObservableObject` with:
  - `enum Access { case notDetermined, denied, authorized }`
  - `@Published private(set) var access: Access`
  - `@Published private(set) var events: [CalendarEventInfo]`
  - `@Published var isEnabled: Bool` (persisted)
  - `var isActive: Bool { isEnabled && access == .authorized }`
  - `func requestAccess() async`
  - `func refresh()`

- [ ] **Step 1: Add the calendars entitlement**

Edit `Coincide/Coincide.entitlements` — add inside the top-level `<dict>` (alongside the existing sandbox + app-group keys):

```xml
	<key>com.apple.security.personal-information.calendars</key>
	<true/>
```

- [ ] **Step 2: Add the usage-description Info.plist key**

In `project.yml`, under `targets: → Coincide: → settings: → base:`, add:

```yaml
        INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription: "Coincide shows your upcoming meetings across your time zones."
```

- [ ] **Step 3: Create `CalendarService`**

Create `Coincide/Calendar/CalendarService.swift`:

```swift
import Foundation
import EventKit
import CoreGraphics

/// The only type that touches EventKit. Reads events for a rolling window and
/// publishes plain `CalendarEventInfo` values. Read-only, local, no network.
@MainActor
final class CalendarService: ObservableObject {
    enum Access { case notDetermined, denied, authorized }

    @Published private(set) var access: Access
    @Published private(set) var events: [CalendarEventInfo] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                Task { await requestAccess() }
            } else {
                events = []
            }
        }
    }

    var isActive: Bool { isEnabled && access == .authorized }

    private static let enabledKey = "calendarEnabled"
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.access = Self.map(EKEventStore.authorizationStatus(for: .event))
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if isActive { refresh() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    static func map(_ status: EKAuthorizationStatus) -> Access {
        switch status {
        case .fullAccess, .authorized: return .authorized
        case .denied, .restricted, .writeOnly: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .authorized : .denied
            if isActive { refresh() }
        } catch {
            access = .denied
        }
    }

    func refresh() {
        guard isActive else { events = []; return }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(48 * 3600),
            calendars: nil
        )
        events = store.events(matching: predicate)
            .map { ek -> CalendarEventInfo in
                let rawTitle = ek.title ?? ""
                return CalendarEventInfo(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: rawTitle.isEmpty ? "(No title)" : rawTitle,
                    start: ek.startDate,
                    end: ek.endDate,
                    isAllDay: ek.isAllDay,
                    calendarColorHex: Self.hex(ek.calendar?.cgColor),
                    location: ek.location
                )
            }
            .sorted { $0.start < $1.start }
    }

    private static func hex(_ color: CGColor?) -> String? {
        guard let comps = color?.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

- [ ] **Step 4: Inject into the app and refresh each minute**

In `Coincide/CoincideApp.swift`, add the state object and inject it. Change the `@StateObject` block and both scene contents:

```swift
    @StateObject private var store = ZoneStore()
    @StateObject private var clock = MinuteClock()
    @StateObject private var presence = WindowPresenceModel()
    @StateObject private var calendar = CalendarService()
```

In the `MenuBarExtra` content closure, add `.environmentObject(calendar)` to `PopoverView()` and pass `calendar` to the label:

```swift
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
                .environmentObject(clock)
                .environmentObject(calendar)
        } label: {
            MenuBarLabelView(store: store, clock: clock, calendar: calendar)
        }
        .menuBarExtraStyle(.window)
```

Add `.environmentObject(calendar)` to the main `Window`'s `RootWindowView()` and to the `Settings`' `SettingsView()`.

- [ ] **Step 5: Build (compile-only) to verify wiring**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`. (Views don't read `calendar` yet; this just verifies the service + entitlement + injection compile. The label signature change is completed in Task 6 — to keep this task self-contained, temporarily accept the new `calendar` parameter in `MenuBarLabelView` by adding `let calendar: CalendarService` as an unused stored property; Task 6 wires it up.)

  In `Coincide/MenuBar/MenuBarLabelView.swift`, add the property to the struct so it compiles now:

```swift
    @ObservedObject var calendar: CalendarService
```

- [ ] **Step 6: Commit**

```bash
git add Coincide/Coincide.entitlements project.yml Coincide/Calendar/CalendarService.swift Coincide/CoincideApp.swift Coincide/MenuBar/MenuBarLabelView.swift
git commit -m "feat(calendar): EventKit CalendarService + permission + app wiring"
```

---

### Task 5: Settings — Calendar section

**Files:**
- Modify: `Coincide/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `CalendarService` (`isEnabled`, `access`, `isActive`).

- [ ] **Step 1: Add the Calendar section to the form**

In `Coincide/Settings/SettingsView.swift`, add `@EnvironmentObject var calendar: CalendarService` to the struct's properties, then add `calendarSection` to the `Form` (after `appearanceSection`):

```swift
    private var calendarSection: some View {
        Section("Calendar") {
            Toggle("Show upcoming meetings", isOn: $calendar.isEnabled)
            if calendar.isEnabled {
                switch calendar.access {
                case .authorized:
                    Label("Calendar access granted", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                case .notDetermined:
                    Text("Allow access when macOS asks.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                case .denied:
                    HStack {
                        Text("Calendar access is off.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }
            Text("Events stay on your Mac — Coincide reads them locally and never sends them anywhere.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
```

Add `calendarSection` into `body`'s `Form`:

```swift
        Form {
            zonesSection
            menuBarSection
            appearanceSection
            calendarSection
            generalSection
            aboutSection
        }
```

Add `import AppKit` at the top of the file if not already present (for `NSWorkspace`).

- [ ] **Step 2: Build to verify**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verification**

Open the project in Xcode with a paid-team signing (App Group needs it), run, open Preferences → Calendar, toggle on, approve the macOS prompt, confirm "Calendar access granted". (On a free team / ad-hoc build the toggle still appears; permission just won't persist.)

- [ ] **Step 4: Commit**

```bash
git add Coincide/Settings/SettingsView.swift
git commit -m "feat(calendar): Settings section to enable calendar + permission status"
```

---

### Task 6: Menu bar — imminent event

**Files:**
- Modify: `Coincide/MenuBar/MenuBarLabelView.swift`

**Interfaces:**
- Consumes: `CalendarService`, `CalendarLogic.nextStarting/isImminent/minutesUntilStart`.

- [ ] **Step 1: Show the imminent event in the label**

In `Coincide/MenuBar/MenuBarLabelView.swift`, replace the `content` view builder so an imminent event (within 30 min) takes priority over the reference time:

```swift
    @ViewBuilder
    private var content: some View {
        if calendar.isActive,
           let next = CalendarLogic.nextStarting(in: calendar.events, now: clock.now),
           CalendarLogic.isImminent(next, now: clock.now, withinMinutes: 30) {
            let mins = CalendarLogic.minutesUntilStart(next, now: clock.now)
            Text("\(next.title) · \(mins)m")
        } else if let ref = store.referenceZone {
            let time = TimeFormatting.time(in: ref.timeZone, at: clock.now, format: store.hourFormat)
            Text("\(ref.flag) \(time)")
        } else {
            Image(systemName: "clock")
        }
    }
```

(The `@ObservedObject var calendar: CalendarService` property was added in Task 4.)

- [ ] **Step 2: Build to verify**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verification**

With calendar enabled and an event starting within 30 min, the menu bar shows `Title · Nm` and reverts to the reference time afterward. Confirm CPU stays ~0% (no `TimelineView`; updates via `MinuteClock`).

- [ ] **Step 4: Commit**

```bash
git add Coincide/MenuBar/MenuBarLabelView.swift
git commit -m "feat(calendar): surface imminent meeting in the menu bar"
```

---

### Task 7: Popover — "Up next" section

**Files:**
- Create: `Coincide/Calendar/EventRowView.swift`
- Modify: `Coincide/MenuBar/PopoverView.swift`

**Interfaces:**
- Consumes: `CalendarService`, `CalendarLogic.upcoming/zoneLines`, `ZoneStore.displayZones`, `MinuteClock`.

- [ ] **Step 1: Create `EventRowView`**

Create `Coincide/Calendar/EventRowView.swift`:

```swift
import SwiftUI

/// One "Up next" row: title + home-zone start time + calendar-color dot;
/// tapping expands the event's time across every tracked zone.
struct EventRowView: View {
    @EnvironmentObject var store: ZoneStore
    let event: CalendarEventInfo
    let now: Date

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Color(hex: event.calendarColorHex) ?? .accentColor)
                        .frame(width: 8, height: 8)
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(TimeFormatting.time(in: store.homeTimeZone, at: event.start, format: store.hourFormat))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                let lines = CalendarLogic.zoneLines(for: event, zones: store.displayZones, format: store.hourFormat)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(lines, id: \.self) { line in
                        HStack(spacing: 6) {
                            Text(line.flag).font(.system(size: 12))
                            Text(line.city).font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(line.time).font(.system(size: 11, weight: .medium)).monospacedDigit()
                            Image(systemName: line.phaseSymbol)
                                .font(.system(size: 8))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 17)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 8)
    }
}

extension Color {
    /// Hex like "#RRGGBB" → Color; nil on bad input.
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7,
              let v = Int(hex.dropFirst(), radix: 16) else { return nil }
        self = Color(.sRGB,
                     red: Double((v >> 16) & 0xFF) / 255,
                     green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}
```

- [ ] **Step 2: Add the section to the popover**

In `Coincide/MenuBar/PopoverView.swift`, add `@EnvironmentObject var calendar: CalendarService`, then insert an "Up next" block between the header `Divider()` and the zone list. Replace the start of `body`'s `VStack` content:

```swift
            header
            Divider()

            if calendar.isActive {
                upNextSection
                Divider()
            }

            if store.zones.isEmpty {
```

Add the `upNextSection` computed property:

```swift
    @ViewBuilder
    private var upNextSection: some View {
        let up = CalendarLogic.upcoming(in: calendar.events, now: clock.now)
        VStack(alignment: .leading, spacing: 0) {
            Text("Up next")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
            if up.isEmpty {
                Text("No meetings today")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 8)
            } else {
                ForEach(up.prefix(3)) { event in
                    EventRowView(event: event, now: clock.now)
                        .environmentObject(store)
                }
            }
        }
    }
```

- [ ] **Step 3: Build to verify**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual verification**

With calendar enabled, the popover shows "Up next" with the next ≤3 meetings; tapping a row expands its per-zone times with day/night glyphs. With no events: "No meetings today".

- [ ] **Step 5: Commit**

```bash
git add Coincide/Calendar/EventRowView.swift Coincide/MenuBar/PopoverView.swift
git commit -m "feat(calendar): Up next section in the popover with per-zone expansion"
```

---

### Task 8: Dashboard — events lane

**Files:**
- Modify: `Coincide/MainWindow/MainDashboardView.swift`

**Interfaces:**
- Consumes: `CalendarService`, `CalendarLogic.timelineBlocks`, the existing `dayStart`/`nameWidth`/`timeWidth` grid metrics.

- [ ] **Step 1: Add the events lane above the bands**

In `Coincide/MainWindow/MainDashboardView.swift`, add `@EnvironmentObject var calendar: CalendarService`. Insert the lane between `axisAndScrubber` and the `Divider()` that precedes `rows` (only when active and there are blocks):

```swift
                readout
                axisAndScrubber
                if calendar.isActive {
                    eventsLane
                }
                Divider().padding(.top, 4)
                rows
```

Add the `eventsLane` view (shares the same `nameWidth`/`timeWidth` insets as the bands so blocks align with the axis):

```swift
    @ViewBuilder
    private var eventsLane: some View {
        let blocks = CalendarLogic.timelineBlocks(for: calendar.events, dayStart: dayStart)
        HStack(spacing: 0) {
            Spacer().frame(width: nameWidth)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    ForEach(blocks) { block in
                        let x = block.startFraction * geo.size.width
                        let w = max(3, (block.endFraction - block.startFraction) * geo.size.width)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill((Color(hex: block.event.calendarColorHex) ?? .accentColor).opacity(0.85))
                            .frame(width: w, height: 16)
                            .overlay(alignment: .leading) {
                                Text(block.event.title)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.leading, 4)
                                    .frame(width: w, alignment: .leading)
                            }
                            .offset(x: x)
                            .help(block.event.title)
                    }
                }
                .frame(height: 18)
            }
            .frame(height: 18)
            Spacer().frame(width: timeWidth)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
```

(`Color(hex:)` is defined in `EventRowView.swift` from Task 7, available app-wide.)

- [ ] **Step 2: Build to verify**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verification**

With calendar enabled, open the dashboard: meetings appear as colored blocks in a lane above the zone bands, horizontally aligned to the same 24h axis (a noon meeting sits above the noon column). Dragging the scrubber moves the marker through them.

- [ ] **Step 4: Run the full unit suite + commit**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — 27 tests.

```bash
git add Coincide/MainWindow/MainDashboardView.swift
git commit -m "feat(calendar): event blocks on the dashboard day/night timeline"
```

---

## Final verification (after all tasks)

- [ ] Full build + tests green:
  `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
- [ ] Manual end-to-end in Xcode with a paid team: enable Calendar in Settings → approve prompt → verify popover "Up next" (+ per-zone expand), menu-bar imminent switch, and dashboard event blocks.
- [ ] README: add a short "Calendar (EventKit, read-only, local)" note and, optionally, a refreshed screenshot once captured.
- [ ] Merge `feature/calendar-integration` → `main` when satisfied.

## Spec coverage check

- Popover "Up next" + per-zone expansion → Task 7. ✅
- Menu bar imminent (`Title · 12m`, 30 min) → Task 6. ✅
- Dashboard shared-axis events lane → Task 8. ✅
- EventKit, read-only, no network, calendars entitlement + usage string → Task 4. ✅
- Opt-in toggle + permission status + denied path → Task 5. ✅
- All-day excluded from timeline/imminent; multi-day clamped; per-zone correctness → Tasks 1–3 (tested). ✅
- Widget untouched; pure logic in `CoincideKit`; reuse `TimeFormatting`/`DayPhase` → enforced throughout. ✅
