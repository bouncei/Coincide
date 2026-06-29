import Foundation

/// Decodable mirror of the fields Coincide needs from a Google Calendar API event.
struct GoogleAPIEvent: Decodable {
    struct DateTime: Decodable {
        let dateTime: String?  // RFC3339, for timed events
        let date: String?      // yyyy-MM-dd, for all-day events
    }
    let id: String?
    let summary: String?
    let status: String?
    let start: DateTime?
    let end: DateTime?
    let location: String?
    let colorId: String?
}

struct GoogleAPIEventsResponse: Decodable {
    let items: [GoogleAPIEvent]
}
