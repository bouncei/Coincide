# Contributing to TimeZones

Thanks for your interest in improving TimeZones! This is a small, focused app —
contributions that keep it minimal and native are very welcome.

## Getting set up

```bash
brew install xcodegen
xcodegen generate
open TimeZones.xcodeproj
```

The `.xcodeproj` is generated and git-ignored. **Never edit it by hand** — make
project/target/build-setting changes in [`project.yml`](project.yml) and re-run
`xcodegen generate`.

## Before you open a PR

1. **Run the tests** — they must pass:
   ```bash
   xcodebuild test -scheme TimeZones -destination 'platform=macOS' \
     -only-testing:TimeZonesKitTests CODE_SIGNING_ALLOWED=NO
   ```
2. **Add tests** for any new time/zone logic. The interesting logic lives in
   `TimeZonesKit/TimeFormatting.swift` and `ZoneStore.swift`, both pure and
   easily testable — keep it that way.
3. **Keep UI logic out of the kit.** `TimeZonesKit` has no SwiftUI/WidgetKit UI
   so it can compile into the app, the widget, and the tests.
4. Match the existing style: small files, clear names, comments only where the
   *why* isn't obvious.

## Good first issues

- Additional widget families (e.g. `.systemLarge`, accessory widgets).
- A working-hours overlap view (highlight when zones are in business hours).
- iCloud / `NSUbiquitousKeyValueStore` sync of the zone list across Macs.
- Localization.

## Reporting bugs

Open an issue with your macOS version, the zones involved, and what you expected
vs. saw. Time bugs are usually about DST or day boundaries — a concrete example
("at 00:30 UTC, Lagos showed …") helps a lot.
