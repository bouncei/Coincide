# Coincide — Google Calendar Source Design

**Date:** 2026-06-26
**Branch:** `feature/google-calendar` (off `feature/calendar-integration`; rebase onto `main` after PR #1 merges)
**Status:** Approved design → ready for implementation plan

## Context & goal

Coincide already has a read-only calendar integration via **Apple EventKit** (PR #1): popover "Up next", menu-bar imminent event, and a dashboard events lane, all driven by a neutral `CalendarEventInfo` model and pure `CoincideKit` logic. EventKit reads only calendars that are in macOS Calendar — and the user's **Google** account is not connected to macOS, so their Google events don't appear.

This feature adds **Google Calendar as a second source**, connected directly in-app via OAuth, so Google events flow into the same surfaces alongside EventKit. The UI and `CoincideKit` logic are reused unchanged; only the data source is new.

## Decisions (confirmed with the user)

- **Add Google *alongside* EventKit** (not replace). Both sources can be on; events merge into the existing surfaces.
- **No-dependency OAuth**: Apple's `ASWebAuthenticationSession` + `URLSession`, **PKCE**, **no client secret**. Tokens in the **Keychain**. (No third-party SDK.)
- **Ship the maintainer's OAuth client ID** in the app (`GoogleConfig`); forkers override. Read-only calendar is a Google "sensitive" scope — works in **Testing** mode now (self as test user); needs Google **verification** before public/App Store release.
- **Read the `primary` Google calendar** for v1 (all-calendars is a follow-up — see Out of scope). *(Revised from "all calendars" after a simplicity review: per-calendar fan-out is N+1 calls + pagination for marginal v1 value.)*
- Read-only. Same surfaces. A per-source on/off in Settings.

### Simplicity review outcomes (Distinguished-Engineer pass)
- **No `CalendarSource` protocol** — only two concrete sources exist; a protocol/framework for a hypothetical third is premature. Use a concrete `CalendarHub`. Extract a protocol later if a third source appears.
- **No dedup on day one** — merged events are concatenated + sorted by start. Add dedup only if real cross-account duplicates appear (then we'll know the right key).
- **Primary calendar only for v1** (above).
- Spend the engineering care on the **OAuth token lifecycle + reconnect/error states**, which is the genuinely hard, failure-prone part.

## Architecture

**Aggregation (app target)**
- **`CalendarHub: ObservableObject`** — owns the two concrete sources (`CalendarService` for EventKit, `GoogleCalendarService` for Google). Publishes a single merged `events: [CalendarEventInfo]` (concatenated from enabled sources, sorted by `start`) and `nextEvent`. **All UI surfaces consume `CalendarHub`** instead of `CalendarService` directly — a mechanical `@EnvironmentObject` repoint in the popover, menu bar, dashboard, and Settings.
- `CalendarService` (EventKit) keeps its current behavior; it's just owned by the hub now.

**Google pieces (app target)**
- **`GoogleConfig`** — committed `clientID` + redirect URI / reverse-client-id scheme (forkers override).
- **`KeychainStore`** — minimal wrapper to persist the Google **refresh token** (+ cached access token + expiry).
- **`GoogleAuth`** — the OAuth lifecycle: `connect() async`, `validAccessToken() async throws -> String` (refreshes near expiry), `disconnect()`. Publishes state `.notConnected` / `.connected(email)` / `.needsReauth`.
- **`GoogleCalendarService: ObservableObject`** — uses `GoogleAuth` for a token, calls the Calendar REST API for `primary`, maps JSON → `CalendarEventInfo`, publishes `events` + connection state.

**`CoincideKit` (pure, unit-tested)**
- **`GoogleEventMapper`** — Google event JSON → `CalendarEventInfo` (timed vs all-day, RFC3339 start/end, title fallback, calendar/event color). Isolated because parsing is the error-prone part.
- **`needsRefresh(expiry:now:skew:) -> Bool`** and **`pkceChallenge(verifier:) -> String`** (S256) — pure token/PKCE helpers, tested without network.

**Platform/config**
- Add the **`com.apple.security.network.client`** sandbox entitlement (the app now makes network calls — only to `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com`).
- Register the **custom URL scheme** (reverse-client-id) for the OAuth redirect in the app Info.plist.
- **Settings → Calendar**: two rows — *macOS Calendar* (existing EventKit toggle) and *Google* (Connect / Disconnect, signed-in email, and status incl. "reconnect needed").

## OAuth & token lifecycle

Installed-app flow, PKCE, no secret:
1. Build auth URL (`accounts.google.com/o/oauth2/v2/auth`): `client_id`, custom-scheme `redirect_uri`, `response_type=code`, `scope=https://www.googleapis.com/auth/calendar.events.readonly`, `code_challenge` (S256) + `code_challenge_method=S256`, random `state`, `access_type=offline`, `prompt=consent`.
2. Present via `ASWebAuthenticationSession`; on redirect, verify `state`, take the `code`.
3. Exchange at `oauth2.googleapis.com/token` (`grant_type=authorization_code`, `code`, `code_verifier`, `client_id`, `redirect_uri`) → `access_token`, `refresh_token`, `expires_in`.
4. Store refresh token (+ access token + expiry) in Keychain. Read the signed-in email from `id_token`/`userinfo` for display.
5. **Refresh**: `validAccessToken()` returns the cached token unless `needsRefresh` (expiry within a skew), else POSTs `grant_type=refresh_token` → new access token. On refresh failure (revoked/expired) → `.needsReauth`.
6. **Disconnect**: clear Keychain (optionally hit the revoke endpoint).

## Data flow & refresh

1. App launch → `GoogleAuth` loads Keychain state. If connected, `GoogleCalendarService` fetches.
2. Fetch: `GET www.googleapis.com/calendar/v3/calendars/primary/events?timeMin&timeMax&singleEvents=true&orderBy=startTime&maxResults=…` for the now→+48h window → map → publish.
3. Refresh triggers: on connect, on app foreground/window open, and every ~5 minutes (lightweight timer, not the per-minute `MinuteClock`).
4. `CalendarHub` recomputes the merged list whenever either source publishes; surfaces update reactively.

## Error handling (operability-first)

- **Offline / transient**: keep the last-fetched events (no crash, no empty flash); surface a quiet "couldn't refresh" state.
- **401**: refresh once; on success refetch, on failure → `.needsReauth`.
- **`.needsReauth`**: Settings shows "Google — reconnect"; the user re-runs Connect. Events from the still-valid EventKit source are unaffected.
- **Keychain failure**: treat as not-connected; never crash.

## Testing

- **Unit (`CoincideKit`)**: `GoogleEventMapper` against sample payloads (timed, all-day, missing/empty fields, color, RFC3339 with offsets); `needsRefresh` boundaries; `pkceChallenge` (known verifier → known S256 challenge). All deterministic, no network.
- **Manual**: full connect (consent) → events appear; force token expiry → silent refresh; disconnect → events gone, EventKit unaffected; offline → last events retained, status shown; `.needsReauth` path.
- `GoogleAuth`/`GoogleCalendarService` stay thin shims so coverage concentrates in the pure helpers.

## Prerequisites (the plan will walk through these)

1. Create a **Google Cloud project**; enable the **Google Calendar API**.
2. **OAuth consent screen**: User type External; add your Google account as a **Test user**; add scope `calendar.events.readonly`.
3. Create an **OAuth client** (iOS/Desktop installed-app type) → obtain the **client ID** and reverse-client-id; put them in `GoogleConfig` and the Info.plist URL scheme.
4. (Before public release) submit for Google **scope verification**.

## Out of scope (clean follow-ups)

All Google calendars (multi-calendar via `calendarList` + per-calendar fetch + a picker); event dedup across sources; write access; Google Tasks; per-builder client-ID override UI; push/webhook sync.
