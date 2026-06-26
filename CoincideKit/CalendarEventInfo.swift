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
