# TimeZones

A minimalist macOS **menu bar app + widget** that keeps your home time and the
zones you work with side by side — so remote workers never miscount the hours
or miss a meeting again.

Built for the very common remote-work problem: *"It's 4pm here — what time is it
for my team in PST? Have they already gone home? Is it tomorrow there yet?"*

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🕒 **Menu bar at a glance** — your chosen reference zone's time always visible
  (e.g. `PDT 2:30 PM`), updated every minute.
- 📋 **One-click popover** — every zone you track, with the local time, GMT
  offset, and a `Tomorrow` / `Yesterday` tag when the day differs.
- 🧩 **Widgets** — small and medium WidgetKit widgets for Notification Center
  and the desktop, sharing the same data as the app.
- 🏠 **Home + unlimited zones** — pick your home zone (auto-detected from your
  Mac) and add as many comparison zones as you like from the full IANA catalog.
- 🌗 **12/24-hour**, drag-to-reorder, launch-at-login.
- 🪶 **Tiny & native** — pure SwiftUI, no dependencies, App Sandbox, no network.

## Architecture

Native SwiftUI. One Xcode project, three targets:

| Target | Type | Purpose |
| --- | --- | --- |
| `TimeZones` | macOS app | `MenuBarExtra` + onboarding/settings window |
| `TimeZonesWidget` | Widget extension | Small/medium WidgetKit widgets |
| `TimeZonesKit` *(shared sources)* | — | Models, store, formatting (compiled into both, plus the test target) |

App and widget share state through an **App Group**
(`group.com.joshuainyang.timezones`) backed by a single JSON blob in
`UserDefaults`. Time math lives in pure, unit-tested helpers in `TimeFormatting`.

```
TimeZonesKit/      SavedZone, ZoneStore, TimeFormatting, TimezoneCatalog
TimeZones/         App, MenuBar/, Onboarding/, Settings/, Resources/
TimeZonesWidget/   WidgetBundle, TimelineProvider, views
TimeZonesKitTests/ Formatting + store unit tests
```

## Build & run

This repo uses [XcodeGen](https://github.com/yonsm/XcodeGen) so the Xcode
project is generated from [`project.yml`](project.yml) (and is git-ignored).

```bash
# 1. Install the generator (once)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Open it
open TimeZones.xcodeproj
```

In Xcode, select the `TimeZones` target → **Signing & Capabilities** → choose
your **Team** (a free personal Apple ID works for local runs), then ⌘R.

### Command line

```bash
# Run the unit tests (no signing required)
xcodebuild test -scheme TimeZones -destination 'platform=macOS' \
  -only-testing:TimeZonesKitTests CODE_SIGNING_ALLOWED=NO

# Compile everything
xcodebuild build -scheme TimeZones -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Shipping to the App Store

The project is structured App Store–ready (App Sandbox + App Group + hardened
runtime). To submit you need a **paid Apple Developer Program** membership:

1. Set `DEVELOPMENT_TEAM` in `project.yml` (or pick your team in Xcode) and run
   `xcodegen generate`.
2. Register the App Group `group.com.joshuainyang.timezones` and both bundle IDs
   (`com.joshuainyang.TimeZones`, `com.joshuainyang.TimeZones.Widget`) on the
   Developer portal — or let Xcode's automatic signing create them.
3. **Product → Archive → Validate App**, then distribute.

> Forking? Change the bundle ID prefix and App Group to your own reverse-DNS
> domain in `project.yml` and the two `*.entitlements` files.

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Please run the
test suite before opening a PR.

## License

[MIT](LICENSE) © 2026 Joshua Inyang
