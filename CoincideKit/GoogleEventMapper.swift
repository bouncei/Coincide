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
        let url = link(for: event)

        if let startStr = event.start?.dateTime, let endStr = event.end?.dateTime,
           let start = parseRFC3339(startStr), let end = parseRFC3339(endStr) {
            return CalendarEventInfo(id: id, title: title, start: start, end: end,
                                     isAllDay: false, calendarColorHex: color, location: event.location, url: url)
        }
        if let startDay = event.start?.date, let endDay = event.end?.date,
           let start = parseDay(startDay), let end = parseDay(endDay) {
            return CalendarEventInfo(id: id, title: title, start: start, end: end,
                                     isAllDay: true, calendarColorHex: color, location: event.location, url: url)
        }
        return nil
    }

    /// The best link to act on an event: prefer the meeting/video-call URL,
    /// then a URL embedded in the location, then the event page.
    static func link(for event: GoogleAPIEvent) -> URL? {
        if let h = event.hangoutLink, let u = URL(string: h) { return u }
        if let video = event.conferenceData?.entryPoints?
            .first(where: { $0.entryPointType == "video" })?.uri,
           let u = URL(string: video) { return u }
        if let loc = event.location, let u = CalendarLogic.firstURL(in: loc) { return u }
        if let html = event.htmlLink, let u = URL(string: html) { return u }
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
