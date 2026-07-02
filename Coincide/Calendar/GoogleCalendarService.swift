import Foundation
import Combine

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEventInfo] = []

    let auth: GoogleAuth
    private var ticker: AnyCancellable?

    init(auth: GoogleAuth) {
        self.auth = auth
        if auth.isConnected { Task { await refresh() } }
        // Periodic refresh while connected (every 5 minutes).
        ticker = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in Task { await self?.refresh() } }
    }

    var isActive: Bool { auth.isConnected }

    func connect() async {
        await auth.connect()
        await refresh()
    }

    func disconnect() {
        auth.disconnect()
        events = []
    }

    func refresh() async {
        guard auth.isConnected else { events = []; return }
        do {
            let token = try await auth.validAccessToken()
            let calendarIds = try await fetchCalendarIds(token: token)
            var collected: [CalendarEventInfo] = []
            for calId in calendarIds {
                let evs = (try? await fetchEvents(calendarId: calId, token: token)) ?? []
                collected.append(contentsOf: evs)
            }
            events = collected.sorted { $0.start < $1.start }
        } catch {
            // Leave the last-known events in place on a transient failure.
        }
    }

    /// All of the user's calendar IDs (`calendarList.list`).
    private func fetchCalendarIds(token: String) async throws -> [String] {
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var (data, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401 {
            let fresh = try await auth.forceRefresh()
            req.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
            (data, resp) = try await URLSession.shared.data(for: req)
        }
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return try JSONDecoder().decode(GoogleCalendarListResponse.self, from: data).items.map(\.id)
    }

    /// Timed-window events for one calendar.
    private func fetchEvents(calendarId: String, token: String) async throws -> [CalendarEventInfo] {
        let now = Date()
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.googleapis.com"
        comps.percentEncodedPath = "/calendar/v3/calendars/\(encodedId)/events"
        comps.queryItems = [
            .init(name: "timeMin", value: iso(now.addingTimeInterval(-3600))),
            .init(name: "timeMax", value: iso(now.addingTimeInterval(48 * 3600))),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime"),
            .init(name: "maxResults", value: "100")
        ]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return GoogleEventMapper.map(try JSONDecoder().decode(GoogleAPIEventsResponse.self, from: data).items)
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
