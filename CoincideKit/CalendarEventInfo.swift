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
    /// A link to act on the event — preferring the meeting/video-call URL,
    /// falling back to the event page. `nil` when neither is available.
    let url: URL?

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool,
         calendarColorHex: String?, location: String?, url: URL? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarColorHex = calendarColorHex
        self.location = location
        self.url = url
    }
}
