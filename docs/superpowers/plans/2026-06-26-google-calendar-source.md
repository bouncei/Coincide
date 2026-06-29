# Google Calendar Source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Google Calendar as a second read-only event source alongside EventKit, connected in-app via OAuth, feeding the existing popover/menu-bar/dashboard surfaces.

**Architecture:** Pure, unit-tested helpers in `CoincideKit` (event mapping, PKCE, refresh decision, merge). In the app target: `GoogleAuth` (ASWebAuthenticationSession + PKCE token lifecycle, Keychain), `GoogleCalendarService` (fetch primary events → map → publish), and a concrete `CalendarHub` that owns the EventKit `CalendarService` + the Google service and publishes a single merged event list the UI consumes. No source protocol, no dedup, primary calendar only.

**Tech Stack:** Swift 5 / SwiftUI, AuthenticationServices (`ASWebAuthenticationSession`), CryptoKit, Security (Keychain), URLSession, XcodeGen, XCTest. No third-party dependencies.

## Global Constraints

- Branch `feature/google-calendar` (off `feature/calendar-integration`). Rebase onto `main` after PR #1 merges.
- **No third-party dependencies.** OAuth via `ASWebAuthenticationSession` + `URLSession`; PKCE; **no client secret**.
- Add **only** the `com.apple.security.network.client` sandbox entitlement. Network calls go only to Google hosts.
- Pure logic in `CoincideKit`; reuse `CalendarEventInfo`, `CalendarLogic`, `TimeFormatting`, `DayPhase`. EventKit code stays as-is (now owned by the hub).
- **Never** add `TimelineView` to the `MenuBarExtra` subtree (prior freeze). Minute updates come from `MinuteClock`.
- Google reads the **`primary`** calendar only (v1). Read-only scope `https://www.googleapis.com/auth/calendar.events.readonly`.
- Merged events = concat of enabled sources, **sorted by start** (no dedup).
- Build/test without signing: `xcodebuild ... CODE_SIGNING_ALLOWED=NO`. After adding files or editing `project.yml`: `export PATH="/usr/local/bin:$PATH" && xcodegen generate`.
- Kit unit suite currently 29 tests (on the EventKit branch this builds from).

## Prerequisite (human, before manual testing — not a code task)

Create the Google OAuth client (the plan references its values):
1. Google Cloud Console → new project → **APIs & Services → Enable** "Google Calendar API".
2. **OAuth consent screen**: User type *External*; add your Google address under **Test users**; add scope `.../auth/calendar.events.readonly`.
3. **Credentials → Create OAuth client ID → Application type: iOS** (installed-app; gives a client ID + a reverse-client-id with **no secret**).
4. Put the client ID + reverse-client-id into `GoogleConfig.swift` and the Info.plist URL scheme (Task 3). Until then, the app compiles with placeholders but the live flow won't authenticate.

---

## File Structure

**Create (CoincideKit, pure):**
- `CoincideKit/GoogleAPIEvent.swift` — Decodable mirror of the Calendar API event JSON.
- `CoincideKit/GoogleEventMapper.swift` — `GoogleAPIEvent` → `CalendarEventInfo`.
- `CoincideKit/GoogleAuthLogic.swift` — `needsRefresh`, `pkceChallenge`, base64url.
- (modify) `CoincideKit/CalendarLogic.swift` — add `mergeSorted`.

**Create (app):**
- `Coincide/Calendar/GoogleConfig.swift` — client ID, redirect, scope.
- `Coincide/Calendar/TokenStore.swift` — `GoogleTokens`, `TokenStore` protocol, `KeychainTokenStore`, `InMemoryTokenStore`.
- `Coincide/Calendar/GoogleAuth.swift` — OAuth lifecycle.
- `Coincide/Calendar/GoogleCalendarService.swift` — fetch + publish.
- `Coincide/Calendar/CalendarHub.swift` — aggregator.

**Create (tests):**
- `CoincideKitTests/GoogleEventMapperTests.swift`, `CoincideKitTests/GoogleAuthLogicTests.swift`.

**Modify (app):**
- `Coincide/Coincide.entitlements` — add network.client.
- `project.yml` — app target: switch Info.plist to an `info:` block adding `CFBundleURLTypes` (and keep existing keys).
- `Coincide/CoincideApp.swift` — create/inject `CalendarHub`.
- `Coincide/MenuBar/PopoverView.swift`, `Coincide/MenuBar/MenuBarLabelView.swift`, `Coincide/MainWindow/MainDashboardView.swift` — read `CalendarHub` instead of `CalendarService`.
- `Coincide/Settings/SettingsView.swift` — two-row Calendar section (EventKit + Google).

---

### Task 1: `GoogleAPIEvent` + `GoogleEventMapper` (pure)

**Files:**
- Create: `CoincideKit/GoogleAPIEvent.swift`, `CoincideKit/GoogleEventMapper.swift`
- Test: `CoincideKitTests/GoogleEventMapperTests.swift`

**Interfaces:**
- Produces:
  - `struct GoogleAPIEvent: Decodable { ... }`, `struct GoogleAPIEventsResponse: Decodable { let items: [GoogleAPIEvent] }`
  - `enum GoogleEventMapper { static func map(_ event: GoogleAPIEvent) -> CalendarEventInfo?; static func map(_ events: [GoogleAPIEvent]) -> [CalendarEventInfo] }`

- [ ] **Step 1: Write the failing test**

Create `CoincideKitTests/GoogleEventMapperTests.swift`:

```swift
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
        let e = decode("""{"id":"z","summary":"Broken","status":"confirmed"}""")
        XCTAssertNil(GoogleEventMapper.map(e))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`
Expected: FAIL — `cannot find 'GoogleAPIEvent'` / `GoogleEventMapper`.

- [ ] **Step 3: Write minimal implementation**

Create `CoincideKit/GoogleAPIEvent.swift`:

```swift
import Foundation

/// Decodable mirror of the fields Coincide needs from a Google Calendar API event.
struct GoogleAPIEvent: Decodable {
    struct DateTime: Decodable {
        let dateTime: String?  // RFC3339, for timed events
        let date: String?      // yyyy-MM-dd, for all-day events
    }
    let id: String?
    let summary: String?
    let status: String?
    let start: DateTime?
    let end: DateTime?
    let location: String?
    let colorId: String?
}

struct GoogleAPIEventsResponse: Decodable {
    let items: [GoogleAPIEvent]
}
```

Create `CoincideKit/GoogleEventMapper.swift`:

```swift
import Foundation

/// Pure mapping from Google Calendar API events to `CalendarEventInfo`.
enum GoogleEventMapper {

    /// Google's default event color palette (colorId "1"–"11").
    static let eventColors: [String: String] = [
        "1": "#A4BDFC", "2": "#7AE7BF", "3": "#DBADFF", "4": "#FF887C",
        "5": "#FBD75B", "6": "#FFB878", "7": "#46D6DB", "8": "#E1E1E1",
        "9": "#5484ED", "10": "#51B749", "11": "#DC2127"
    ]

    static func map(_ event: GoogleAPIEvent) -> CalendarEventInfo? {
        guard event.status != "cancelled" else { return nil }
        let id = event.id ?? UUID().uuidString
        let title = (event.summary?.isEmpty == false) ? event.summary! : "(No title)"
        let color = event.colorId.flatMap { eventColors[$0] }

        if let startStr = event.start?.dateTime, let endStr = event.end?.dateTime,
           let start = parseRFC3339(startStr), let end = parseRFC3339(endStr) {
            return CalendarEventInfo(id: id, title: title, start: start, end: end,
                                     isAllDay: false, calendarColorHex: color, location: event.location)
        }
        if let startDay = event.start?.date, let endDay = event.end?.date,
           let start = parseDay(startDay), let end = parseDay(endDay) {
            return CalendarEventInfo(id: id, title: title, start: start, end: end,
                                     isAllDay: true, calendarColorHex: color, location: event.location)
        }
        return nil
    }

    static func map(_ events: [GoogleAPIEvent]) -> [CalendarEventInfo] {
        events.compactMap(map)
    }

    static func parseRFC3339(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func parseDay(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — count rises from 29 to 34.

- [ ] **Step 5: Commit**

```bash
cd /Users/joshuainyang/Documents/Coincide
git add CoincideKit/GoogleAPIEvent.swift CoincideKit/GoogleEventMapper.swift CoincideKitTests/GoogleEventMapperTests.swift
git commit -m "feat(gcal): Google event JSON model + mapper to CalendarEventInfo"
```

---

### Task 2: PKCE / refresh / merge helpers (pure)

**Files:**
- Create: `CoincideKit/GoogleAuthLogic.swift`
- Modify: `CoincideKit/CalendarLogic.swift`
- Test: `CoincideKitTests/GoogleAuthLogicTests.swift`

**Interfaces:**
- Produces:
  - `enum GoogleAuthLogic { static func needsRefresh(expiry: Date?, now: Date, skew: TimeInterval) -> Bool; static func pkceChallenge(verifier: String) -> String }`
  - `extension Data { func base64URLEncodedString() -> String }`
  - `CalendarLogic.mergeSorted(_ lists: [[CalendarEventInfo]]) -> [CalendarEventInfo]`

- [ ] **Step 1: Write the failing test**

Create `CoincideKitTests/GoogleAuthLogicTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`
Expected: FAIL — `cannot find 'GoogleAuthLogic'` / `mergeSorted`.

- [ ] **Step 3: Write minimal implementation**

Create `CoincideKit/GoogleAuthLogic.swift`:

```swift
import Foundation
import CryptoKit

/// Pure OAuth/PKCE helpers — no network, no Keychain.
enum GoogleAuthLogic {
    /// True if there's no token or it expires within `skew` seconds.
    static func needsRefresh(expiry: Date?, now: Date, skew: TimeInterval = 60) -> Bool {
        guard let expiry else { return true }
        return now.addingTimeInterval(skew) >= expiry
    }

    /// PKCE S256 challenge: base64url(SHA256(verifier)).
    static func pkceChallenge(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

Append to `CoincideKit/CalendarLogic.swift` (inside `enum CalendarLogic`):

```swift
    /// Concatenate event lists from multiple sources and sort by start.
    static func mergeSorted(_ lists: [[CalendarEventInfo]]) -> [CalendarEventInfo] {
        lists.flatMap { $0 }.sorted { $0.start < $1.start }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: PASS — count 34 → 37.

- [ ] **Step 5: Commit**

```bash
git add CoincideKit/GoogleAuthLogic.swift CoincideKit/CalendarLogic.swift CoincideKitTests/GoogleAuthLogicTests.swift
git commit -m "feat(gcal): PKCE challenge, refresh decision, and source merge helpers"
```

---

### Task 3: Config, entitlement, URL scheme, token store

**Files:**
- Create: `Coincide/Calendar/GoogleConfig.swift`, `Coincide/Calendar/TokenStore.swift`
- Modify: `Coincide/Coincide.entitlements`, `project.yml`

**Interfaces:**
- Produces:
  - `enum GoogleConfig { static let clientID, redirectScheme, redirectURI, scope: String }`
  - `struct GoogleTokens: Codable { var refreshToken: String; var accessToken: String?; var expiry: Date?; var email: String? }`
  - `protocol TokenStore { func load() -> GoogleTokens?; func save(_ tokens: GoogleTokens); func clear() }`
  - `final class KeychainTokenStore: TokenStore`, `final class InMemoryTokenStore: TokenStore`

- [ ] **Step 1: Add the network entitlement**

Edit `Coincide/Coincide.entitlements`, add inside the top-level `<dict>`:

```xml
	<key>com.apple.security.network.client</key>
	<true/>
```

- [ ] **Step 2: Add the OAuth redirect URL scheme to the app's Info.plist (via project.yml)**

In `project.yml`, replace the `Coincide` app target's Info.plist build settings. Remove `GENERATE_INFOPLIST_FILE: YES` and the `INFOPLIST_KEY_*` lines, and add an `info:` block. The target's `settings.base` keeps `PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME`, `CODE_SIGN_ENTITLEMENTS`, `ASSETCATALOG_*`, `COMBINE_HIDPI_IMAGES`. Add under the `Coincide:` target (sibling of `settings:`):

```yaml
    info:
      path: Coincide/Info.plist
      properties:
        LSUIElement: true
        CFBundleDisplayName: Coincide
        NSHumanReadableCopyright: "© 2026"
        NSCalendarsFullAccessUsageDescription: "Coincide shows your upcoming meetings across your time zones."
        CFBundleURLTypes:
          - CFBundleURLName: dev.bouncei.Coincide.oauth
            CFBundleURLSchemes:
              - com.googleusercontent.apps.REPLACE_WITH_CLIENT_ID
```

(XcodeGen generates `Coincide/Info.plist` from these properties plus standard keys. The scheme value must match `GoogleConfig.redirectScheme`.)

- [ ] **Step 3: Create `GoogleConfig`**

Create `Coincide/Calendar/GoogleConfig.swift`:

```swift
import Foundation

/// OAuth client configuration. Replace the placeholders with your Google Cloud
/// OAuth client (iOS/installed-app type — no secret). Forkers override these.
enum GoogleConfig {
    static let clientID = "REPLACE_WITH_CLIENT_ID.apps.googleusercontent.com"
    /// The reverse-client-id scheme; must match the Info.plist CFBundleURLSchemes entry.
    static let redirectScheme = "com.googleusercontent.apps.REPLACE_WITH_CLIENT_ID"
    static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
    static let scope = "https://www.googleapis.com/auth/calendar.events.readonly"

    static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}
```

- [ ] **Step 4: Create the token store**

Create `Coincide/Calendar/TokenStore.swift`:

```swift
import Foundation
import Security

struct GoogleTokens: Codable {
    var refreshToken: String
    var accessToken: String?
    var expiry: Date?
    var email: String?
}

protocol TokenStore {
    func load() -> GoogleTokens?
    func save(_ tokens: GoogleTokens)
    func clear()
}

/// Persists the Google tokens as a JSON blob in the login Keychain.
final class KeychainTokenStore: TokenStore {
    private let service = "dev.bouncei.Coincide.google"
    private let account = "tokens"

    func load() -> GoogleTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    func save(_ tokens: GoogleTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query = baseQuery()
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

/// In-memory store for unit tests / previews.
final class InMemoryTokenStore: TokenStore {
    private var tokens: GoogleTokens?
    func load() -> GoogleTokens? { tokens }
    func save(_ tokens: GoogleTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}
```

- [ ] **Step 5: Regenerate + build**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`. Also confirm the generated `Coincide/Info.plist` contains `CFBundleURLTypes`.

- [ ] **Step 6: Commit**

```bash
git add Coincide/Calendar/GoogleConfig.swift Coincide/Calendar/TokenStore.swift Coincide/Coincide.entitlements project.yml Coincide/Info.plist
git commit -m "feat(gcal): config, network entitlement, OAuth redirect scheme, Keychain token store"
```

---

### Task 4: `GoogleAuth` (OAuth lifecycle)

**Files:**
- Create: `Coincide/Calendar/GoogleAuth.swift`

**Interfaces:**
- Consumes: `GoogleConfig`, `GoogleTokens`/`TokenStore`/`KeychainTokenStore`, `GoogleAuthLogic.needsRefresh`/`pkceChallenge`.
- Produces:
  - `@MainActor final class GoogleAuth: ObservableObject` with `enum State: Equatable { case notConnected; case connected(String); case needsReauth }`, `@Published private(set) var state: State`, `func connect() async`, `func disconnect()`, `func validAccessToken() async throws -> String`.

- [ ] **Step 1: Implement `GoogleAuth`**

Create `Coincide/Calendar/GoogleAuth.swift`:

```swift
import Foundation
import AuthenticationServices

@MainActor
final class GoogleAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    enum State: Equatable {
        case notConnected
        case connected(String)   // email (or "Google")
        case needsReauth
    }
    enum AuthError: Error { case cancelled, badResponse, refreshFailed }

    @Published private(set) var state: State = .notConnected

    private let store: TokenStore
    private var session: ASWebAuthenticationSession?

    init(store: TokenStore = KeychainTokenStore()) {
        self.store = store
        super.init()
        if let t = store.load() {
            state = .connected(t.email ?? "Google")
        }
    }

    var isConnected: Bool { if case .connected = state { return true }; return false }

    // MARK: Connect (interactive)

    func connect() async {
        let verifier = Self.randomString(64)
        let challenge = GoogleAuthLogic.pkceChallenge(verifier: verifier)
        let stateParam = Self.randomString(24)
        var comps = URLComponents(string: GoogleConfig.authEndpoint)!
        comps.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleConfig.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: stateParam),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent")
        ]
        guard let authURL = comps.url else { return }

        do {
            let callback = try await present(authURL: authURL)
            guard let items = URLComponents(string: callback.absoluteString)?.queryItems,
                  items.first(where: { $0.name == "state" })?.value == stateParam,
                  let code = items.first(where: { $0.name == "code" })?.value
            else { throw AuthError.badResponse }
            try await exchange(code: code, verifier: verifier)
        } catch {
            // Cancelled or failed — leave prior state untouched on cancel.
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin,
               !isConnected {
                state = .notConnected
            }
        }
    }

    private func present(authURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(
                url: authURL, callbackURLScheme: GoogleConfig.redirectScheme
            ) { url, err in
                if let url { cont.resume(returning: url) }
                else { cont.resume(throwing: err ?? AuthError.cancelled) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.session = s
            s.start()
        }
    }

    // MARK: Token exchange + refresh

    private func exchange(code: String, verifier: String) async throws {
        let body = [
            "client_id": GoogleConfig.clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": GoogleConfig.redirectURI,
            "grant_type": "authorization_code"
        ]
        let json = try await postToken(body)
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Double else { throw AuthError.badResponse }
        let email = Self.email(fromIDToken: json["id_token"] as? String)
        let tokens = GoogleTokens(refreshToken: refresh, accessToken: access,
                                  expiry: Date().addingTimeInterval(expiresIn), email: email)
        store.save(tokens)
        state = .connected(email ?? "Google")
    }

    func validAccessToken() async throws -> String {
        guard var tokens = store.load() else { state = .notConnected; throw AuthError.refreshFailed }
        if !GoogleAuthLogic.needsRefresh(expiry: tokens.expiry, now: Date()),
           let access = tokens.accessToken { return access }
        // refresh
        let body = [
            "client_id": GoogleConfig.clientID,
            "refresh_token": tokens.refreshToken,
            "grant_type": "refresh_token"
        ]
        do {
            let json = try await postToken(body)
            guard let access = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double else { throw AuthError.refreshFailed }
            tokens.accessToken = access
            tokens.expiry = Date().addingTimeInterval(expiresIn)
            store.save(tokens)
            return access
        } catch {
            state = .needsReauth
            throw AuthError.refreshFailed
        }
    }

    func disconnect() {
        store.clear()
        state = .notConnected
    }

    // MARK: Helpers

    private func postToken(_ body: [String: String]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: GoogleConfig.tokenEndpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw AuthError.badResponse }
        return json
    }

    private static func formEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    private static func randomString(_ length: Int) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
    }

    /// Decode the email claim from a JWT id_token without verification (display only).
    private static func email(fromIDToken token: String?) -> String? {
        guard let parts = token?.split(separator: "."), parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["email"] as? String
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        DispatchQueue.main.sync { NSApplication.shared.windows.first ?? ASPresentationAnchor() }
    }
}
```

- [ ] **Step 2: Regenerate + build**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Coincide/Calendar/GoogleAuth.swift
git commit -m "feat(gcal): GoogleAuth OAuth lifecycle (PKCE connect, refresh, disconnect)"
```

---

### Task 5: `GoogleCalendarService`

**Files:**
- Create: `Coincide/Calendar/GoogleCalendarService.swift`

**Interfaces:**
- Consumes: `GoogleAuth`, `GoogleConfig`, `GoogleAPIEventsResponse`/`GoogleEventMapper`, `CalendarEventInfo`.
- Produces: `@MainActor final class GoogleCalendarService: ObservableObject` with `@Published private(set) var events: [CalendarEventInfo]`, `let auth: GoogleAuth`, `var isActive: Bool` (auth connected), `func refresh() async`.

- [ ] **Step 1: Implement the service**

Create `Coincide/Calendar/GoogleCalendarService.swift`:

```swift
import Foundation
import Combine

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEventInfo] = []

    let auth: GoogleAuth
    private var ticker: AnyCancellable?

    init(auth: GoogleAuth = GoogleAuth()) {
        self.auth = auth
        if auth.isConnected { Task { await refresh() } }
        // Periodic refresh while connected (every 5 minutes).
        ticker = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in Task { await self?.refresh() } }
    }

    var isActive: Bool { auth.isConnected }

    func connect() async {
        await auth.connect()
        await refresh()
    }

    func disconnect() {
        auth.disconnect()
        events = []
    }

    func refresh() async {
        guard auth.isConnected else { events = []; return }
        do {
            let token = try await auth.validAccessToken()
            let now = Date()
            var comps = URLComponents(string:
                "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            comps.queryItems = [
                .init(name: "timeMin", value: iso(now.addingTimeInterval(-3600))),
                .init(name: "timeMax", value: iso(now.addingTimeInterval(48 * 3600))),
                .init(name: "singleEvents", value: "true"),
                .init(name: "orderBy", value: "startTime"),
                .init(name: "maxResults", value: "100")
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return } // keep last events
            let decoded = try JSONDecoder().decode(GoogleAPIEventsResponse.self, from: data)
            events = GoogleEventMapper.map(decoded.items)
        } catch {
            // Offline / refresh failure: keep last events; auth.state already reflects reauth needs.
        }
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
```

- [ ] **Step 2: Build**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Coincide/Calendar/GoogleCalendarService.swift
git commit -m "feat(gcal): GoogleCalendarService fetches primary events"
```

---

### Task 6: `CalendarHub` + app wiring

**Files:**
- Create: `Coincide/Calendar/CalendarHub.swift`
- Modify: `Coincide/CoincideApp.swift`

**Interfaces:**
- Consumes: `CalendarService` (EventKit), `GoogleCalendarService`, `CalendarLogic.mergeSorted`.
- Produces: `@MainActor final class CalendarHub: ObservableObject` with `let eventKit: CalendarService`, `let google: GoogleCalendarService`, `@Published private(set) var events: [CalendarEventInfo]`, `var isActive: Bool`.

- [ ] **Step 1: Implement the hub**

Create `Coincide/Calendar/CalendarHub.swift`:

```swift
import Foundation
import Combine

/// Owns the concrete calendar sources and publishes a single merged event list.
@MainActor
final class CalendarHub: ObservableObject {
    let eventKit: CalendarService
    let google: GoogleCalendarService

    @Published private(set) var events: [CalendarEventInfo] = []

    private var cancellables: Set<AnyCancellable> = []

    init(eventKit: CalendarService = CalendarService(),
         google: GoogleCalendarService = GoogleCalendarService()) {
        self.eventKit = eventKit
        self.google = google
        recompute()
        // Re-merge and re-publish whenever either source changes.
        eventKit.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.recompute() } }
            .store(in: &cancellables)
        google.$events
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        google.auth.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.recompute(); self?.objectWillChange.send() } }
            .store(in: &cancellables)
    }

    var isActive: Bool { eventKit.isActive || google.isActive }

    private func recompute() {
        events = CalendarLogic.mergeSorted([eventKit.events, google.events])
    }
}
```

- [ ] **Step 2: Wire into the app**

In `Coincide/CoincideApp.swift`, replace the `@StateObject private var calendar = CalendarService()` line with:

```swift
    @StateObject private var calendar = CalendarHub()
```

The injections (`.environmentObject(calendar)` and `MenuBarLabelView(... calendar: calendar)`) stay — `calendar` is now a `CalendarHub`. Update the `MenuBarLabelView` property type in Task 7.

- [ ] **Step 3: Build**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: FAIL initially — the UI still types its env object as `CalendarService`. This is expected; Task 7 repoints the surfaces. To keep this task independently green, also do Task 7's edits before building. (Tasks 6 and 7 are a single reviewable unit — implement both, then build once.)

- [ ] **Step 4: Commit (with Task 7)**

Commit after Task 7's build passes.

---

### Task 7: Repoint UI to `CalendarHub` + Google Settings row

**Files:**
- Modify: `Coincide/MenuBar/MenuBarLabelView.swift`, `Coincide/MenuBar/PopoverView.swift`, `Coincide/MainWindow/MainDashboardView.swift`, `Coincide/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `CalendarHub` (`events`, `isActive`, `eventKit`, `google`), `GoogleAuth.State`.

- [ ] **Step 1: Repoint the three glance surfaces**

These three only use `calendar.isActive` and `calendar.events`, so the change is purely the type:
- `MenuBarLabelView.swift`: change `@ObservedObject var calendar: CalendarService` → `@ObservedObject var calendar: CalendarHub`.
- `PopoverView.swift`: change `@EnvironmentObject var calendar: CalendarService` → `@EnvironmentObject var calendar: CalendarHub`.
- `MainDashboardView.swift`: change `@EnvironmentObject var calendar: CalendarService` → `@EnvironmentObject var calendar: CalendarHub`.

(`CalendarHub` exposes `events` and `isActive` with the same names/types, so no other lines change.)

- [ ] **Step 2: Settings — two rows**

In `Coincide/Settings/SettingsView.swift`, change `@EnvironmentObject var calendar: CalendarService` → `@EnvironmentObject var calendar: CalendarHub`, and replace `calendarSection` with:

```swift
    private var calendarSection: some View {
        Section("Calendar") {
            // macOS Calendar (EventKit)
            Toggle("macOS Calendar", isOn: Binding(
                get: { calendar.eventKit.isEnabled },
                set: { calendar.eventKit.isEnabled = $0 }
            ))
            if calendar.eventKit.isEnabled, calendar.eventKit.access == .denied {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }

            // Google
            switch calendar.google.auth.state {
            case .connected(let email):
                LabeledContent("Google", value: email)
                Button("Disconnect Google") { calendar.google.disconnect() }
            case .needsReauth:
                LabeledContent("Google", value: "Reconnect needed")
                Button("Reconnect Google") { Task { await calendar.google.connect() } }
            case .notConnected:
                Button("Connect Google account") { Task { await calendar.google.connect() } }
            }

            Text("Events stay on your Mac — EventKit reads locally; Google is read-only over your account.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
```

- [ ] **Step 3: Regenerate + build**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the full kit suite (no regression)**

Run: `xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: 37 passing.

- [ ] **Step 5: Commit (Tasks 6 + 7)**

```bash
git add Coincide/Calendar/CalendarHub.swift Coincide/CoincideApp.swift Coincide/MenuBar/MenuBarLabelView.swift Coincide/MenuBar/PopoverView.swift Coincide/MainWindow/MainDashboardView.swift Coincide/Settings/SettingsView.swift
git commit -m "feat(gcal): CalendarHub aggregator + Google Settings row; repoint UI to hub"
```

---

### Task 8: README + final verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document the Google source**

In `README.md`, under the calendar bullet, add a sub-note and a "Connecting Google" subsection describing: requires creating a Google Cloud OAuth client (iOS type), filling `GoogleConfig.swift` + the Info.plist URL scheme, and that read-only calendar scope needs Google verification before public release. Add this paragraph after the Features list:

```markdown
### Connecting Google Calendar

Coincide reads Google events via OAuth (read-only, `calendar.events.readonly`).
To enable it in your own build: create a Google Cloud project, enable the
Calendar API, configure the OAuth consent screen (add yourself as a test user),
create an **iOS** OAuth client, and put the client ID + reverse-client-id into
`Coincide/Calendar/GoogleConfig.swift` and the `CFBundleURLTypes` entry in
`project.yml`. Tokens are stored in the Keychain; nothing is sent anywhere but
Google. Public distribution requires Google's one-time scope verification.
```

- [ ] **Step 2: Final build + full kit suite**

Run: `export PATH="/usr/local/bin:$PATH" && cd /Users/joshuainyang/Documents/Coincide && xcodegen generate && xcodebuild build -scheme Coincide -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "\*\* BUILD" && xcodebuild test -scheme Coincide -destination 'platform=macOS' -only-testing:CoincideKitTests CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Executed|TEST"`
Expected: `** BUILD SUCCEEDED **`, 37 tests passing.

- [ ] **Step 3: Manual verification (requires the OAuth client + a signed build)**

With `GoogleConfig`/Info.plist filled in and a development-signed build: Settings → Calendar → **Connect Google account** → consent in the system browser sheet → events appear in the popover/menu bar/dashboard merged with EventKit. Disconnect removes them. Toggle EventKit independently.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(gcal): document Google Calendar connection + setup"
```

---

## Self-review

**Spec coverage:** alongside-EventKit (Task 6 hub) ✅; no-dep OAuth/PKCE/Keychain (Tasks 2–4) ✅; ship client ID (Task 3) ✅; primary-only fetch (Task 5) ✅; concat+sort merge, no dedup (Task 2/6) ✅; network entitlement + URL scheme (Task 3) ✅; two-row Settings + reconnect state (Task 7) ✅; error handling keeps last events / needsReauth (Tasks 4–5) ✅; pure tests for mapper/PKCE/refresh/merge (Tasks 1–2) ✅; README + verification (Task 8) ✅.

**Placeholder scan:** The only intentional placeholders are the OAuth `clientID`/redirect scheme (human prerequisite) and the PKCE test's expected value (the implementer note gives the exact RFC 7636 string `E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM`). No "TODO/handle errors" placeholders.

**Type consistency:** `CalendarEventInfo` initializer matches the EventKit branch; `CalendarService.events/isEnabled/access/isActive` reused as-is; `CalendarHub.events/isActive` mirror what the UI already reads from `CalendarService`; `GoogleAuth.State` cases match Settings' switch.

## Notes / risks

- Tasks 6 + 7 are one reviewable unit (the hub repoint only builds with the UI changes) — implement together, single build/commit.
- OAuth is verified by build + manual (interactive + network); the correctness-critical pieces (mapping, PKCE, refresh decision, merge) are pure-unit-tested.
- `ASWebAuthenticationSession` needs a window anchor; for a menu-bar app, connect from the Settings window (which exists when the user clicks Connect).
