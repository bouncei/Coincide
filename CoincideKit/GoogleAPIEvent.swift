import Foundation

/// Decodable mirror of the fields Coincide needs from a Google Calendar API event.
struct GoogleAPIEvent: Decodable {
    struct DateTime: Decodable {
        let dateTime: String?  // RFC3339, for timed events
        let date: String?      // yyyy-MM-dd, for all-day events
    }
    struct ConferenceData: Decodable {
        struct EntryPoint: Decodable {
            let entryPointType: String?  // "video", "phone", "more", …
            let uri: String?
        }
        let entryPoints: [EntryPoint]?
    }
    let id: String?
    let summary: String?
    let status: String?
    let start: DateTime?
    let end: DateTime?
    let location: String?
    let colorId: String?
    let htmlLink: String?       // event page on Google Calendar (web)
    let hangoutLink: String?    // Google Meet quick link
    let conferenceData: ConferenceData?
}

struct GoogleAPIEventsResponse: Decodable {
    let items: [GoogleAPIEvent]
}

/// One entry from the user's calendar list (`calendarList.list`).
struct GoogleCalendarListEntry: Decodable {
    let id: String
    let primary: Bool?
    let selected: Bool?
}

struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarListEntry]
}
