import SwiftUI
import AppKit

/// The always-visible menu bar item. Shows the reference zone's abbreviation
/// and time (e.g. "PDT 2:30 PM"), refreshing every minute via `MinuteClock`.
/// Falls back to a clock glyph until the user has set up at least one zone.
///
/// IMPORTANT: this view must NOT use `TimelineView` — inside a `MenuBarExtra`
/// label that triggers an infinite status-item re-layout loop. The per-minute
/// refresh comes from `MinuteClock` instead.
struct MenuBarLabelView: View {
    @ObservedObject var store: ZoneStore
    @ObservedObject var clock: MinuteClock
    @ObservedObject var calendar: CalendarService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content
            .onAppear {
                // Kick off onboarding the first time the app runs.
                if !store.didCompleteOnboarding {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: WindowID.main)
                }
            }
    }

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
}
