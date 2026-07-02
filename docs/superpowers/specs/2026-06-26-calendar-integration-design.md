# Coincide — Calendar Integration (v1) Design

**Date:** 2026-06-26
**Branch:** `feature/calendar-integration`
**Status:** Approved design → ready for implementation plan

## Context & goal

Coincide is a macOS menu-bar + widget timezone app. Today it shows the current
time across the user's tracked zones (popover, dashboard with a time scrubber +
day/night bands, widget). This feature adds **calendar context** so the user
sees their meetings *in the context of their zones* — the thing a generic
calendar app can't do: a "3:00 PM" meeting annotated as "8:00 AM in LA, 11:00 PM
in Sydney 🌙 (they're asleep)."

The user works remotely from Abuja (Africa/Lagos) on PST/EST hours, so knowing
how a meeting lands across zones — and what's coming up next — directly serves
the app's core job.

## Decisions (confirmed with the user)

- **Primary surfaces (v1):** (A) a **glance** at upcoming meetings in the
  popover and menu bar, each shown across the tracked zones; and (B) meetings
  **overlaid on the dashboard's day/night timeline**.
- **Data source:** **Apple EventKit** (native). Reads the user's Google events
  (and iCloud/Exchange) from macOS Calendar with a permission prompt — no OAuth,
  **no network**, private and offline-friendly. (The direct Google Calendar API
  is explicitly *not* used.)
- **Read-only** in v1 — display events only; no create/edit.
- **Menu bar behavior:** normally the reference-zone time; when the next event
  is within **30 minutes**, show `Title · 12m`, reverting after it starts.
- **Defaults:** all calendars shown; all-day events as a chip (not on the
  timeline); **no calendar in the widget** in v1; calendar is **opt-in** via a
  Settings toggle that triggers the permission prompt.

## Experience

**Popover — "Up next"**
A compact section above the zone list showing the next 1–3 events (today +
tomorrow): title, start time in the home zone, and a calendar-color dot.
Expanding an event reveals its time across **every tracked zone** with day/night
glyphs — the signature value.

**Menu bar**
Reference-zone time by default; within 30 min of the next event, switches to
`Standup · 12m`, then reverts.

**Dashboard — "Events" lane**
A single events lane above the zone bands, sharing the **same 24-hour axis**.
Because a meeting is one instant, a block at the noon mark lines up vertically
with noon across every zone's band below it — read a column to see "daytime in
Lagos, night in Sydney." The scrubber's "now" line passes through the blocks.

**Settings**
A new **Calendar** section: enable toggle, permission status, and a button to
open System Settings when access is denied. (Per-calendar filtering is a
fast-follow, not in v1.)

## Architecture

Follows Coincide's existing split: pure logic in `CoincideKit`, platform code in
the app target, nothing in the widget.

### Permissions (app target only)
- Add the App Sandbox **calendars** entitlement
  (`com.apple.security.personal-information.calendars`) and an Info.plist usage
  string (`NSCalendarsUsageDescription` / full-access key on macOS 14+).
- **No network entitlement** — EventKit is entirely local.
- Request access via `EKEventStore.requestFullAccessToEvents()` (macOS 14+).

### `CoincideKit` (pure, unit-tested)
- `CalendarEventInfo` — `id, title, start, end, isAllDay, calendarColorHex,
  location?` (Codable/Hashable). `EKEvent` never leaks past the service.
- Pure helpers reusing existing `TimeFormatting` + `DayPhase`:
  - `nextEvent(in:now:)` — the next upcoming timed event.
  - `minutesUntil(_:now:)` and `isImminent(_:now:threshold:)`.
  - per-zone event lines (time + day/night per tracked zone).
  - all-day exclusion and multi-day clamping helpers for the timeline.

### App target
- `CalendarService: ObservableObject` — the only type touching `EKEventStore`:
  holds authorization status, requests access, fetches a rolling now→+48h window
  via an `EKEventStore` predicate, maps `EKEvent` → `CalendarEventInfo`, and
  publishes `events` + `nextEvent`. Refreshes on `.EKEventStoreChanged` and
  re-evaluates "next/imminent" on each `MinuteClock` tick (no constant polling).
- Injected into the environment alongside `store` and `clock`.
- Consumers:
  - `MenuBarLabelView` — imminent event → `Title · Nm`.
  - `PopoverView` — new "Up next" section + `EventRowView` (expandable per-zone).
  - `MainDashboardView` — the shared-axis "Events" lane.
  - `SettingsView` — new Calendar section.

## Data flow & refresh

1. Launch / toggle-on → `CalendarService` checks authorization.
2. If authorized → fetch now→+48h once → publish `events` + `nextEvent`.
3. `.EKEventStoreChanged` → refetch (edits in Calendar appear).
4. `MinuteClock` tick → recompute next/imminent (cheap; refetch only
   periodically, e.g. every few minutes, or on change).
5. SwiftUI surfaces update reactively.

## Edge cases / error handling

- **notDetermined** → calendar UI hidden until the user opts in (toggle triggers
  the prompt).
- **denied / restricted** → "Calendar access is off" row + "Open System
  Settings" button; rest of the app unaffected.
- **No events** → "No meetings today"; empty timeline lane.
- **All-day** → chip; excluded from timeline and from imminent.
- **Multi-day / overlapping** → clamped to the visible window; overlaps stack in
  the lane; popover shows the next few.
- **Per-zone correctness** → computed from each event's absolute start instant,
  independent of the event's own timezone.

## Testing

- **Unit (`CoincideKit`):** next-event selection, imminent thresholds, per-zone
  line formatting, all-day exclusion, multi-day clamping — all with fixed dates,
  no EventKit.
- **Manual:** real Calendar events across popover / menu bar / timeline; the
  permission-denied path; toggling Calendar on/off.
- `CalendarService` stays a thin shim, so coverage concentrates in pure helpers.

## Privacy

Events never leave the Mac — EventKit is local, no network entitlement is added.
Worth a line in the README and the Settings Calendar section.

## Out of scope (clean later adds)

Creating/editing events; calendar in the widget; per-calendar filtering; the
cross-zone "slot finder"; reminders/notifications with zone context; the direct
Google Calendar API.
