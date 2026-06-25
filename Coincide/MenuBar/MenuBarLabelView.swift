import SwiftUI

/// The always-visible menu bar item. Shows the reference zone's abbreviation
/// and time (e.g. "PDT 2:30 PM"), refreshing every minute. Falls back to a
/// clock glyph until the user has set up at least one zone.
struct MenuBarLabelView: View {
    @ObservedObject var store: ZoneStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content
            .onAppear {
                // Kick off onboarding the first time the app runs.
                if !store.didCompleteOnboarding {
                    openWindow(id: WindowID.main)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let ref = store.referenceZone {
            TimelineView(.everyMinute) { context in
                let time = TimeFormatting.time(in: ref.timeZone, at: context.date, format: store.hourFormat)
                let abbr = TimeFormatting.abbreviation(for: ref.timeZone, at: context.date)
                Image(systemName: "clock")
                Text("\(abbr) \(time)")
            }
        } else {
            Image(systemName: "clock")
        }
    }
}
