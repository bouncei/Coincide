import WidgetKit
import Foundation

struct ZoneEntry: TimelineEntry {
    let date: Date
    let state: StoreState
}

/// Reads the shared App Group snapshot and emits one entry per minute for the
/// next hour, then asks WidgetKit to refresh. The app also forces an immediate
/// reload whenever the user edits zones.
struct ZoneTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZoneEntry {
        ZoneEntry(date: Date(), state: ZoneStore.loadSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (ZoneEntry) -> Void) {
        completion(ZoneEntry(date: Date(), state: ZoneStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZoneEntry>) -> Void) {
        let state = ZoneStore.loadSnapshot()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = Date()
        let startOfMinute = cal.date(bySetting: .second, value: 0, of: now) ?? now

        var entries: [ZoneEntry] = []
        for minute in 0..<60 {
            if let date = cal.date(byAdding: .minute, value: minute, to: startOfMinute) {
                entries.append(ZoneEntry(date: date, state: state))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
