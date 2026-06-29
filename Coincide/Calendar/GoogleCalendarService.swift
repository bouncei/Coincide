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
            let now = Date()
            var comps = URLComponents(string:
                "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            comps.queryItems = [
                .init(name: "timeMin", value: iso(now.addingTimeInterval(-3600))),
                .init(name: "timeMax", value: iso(now.addingTimeInterval(48 * 3600))),
                .init(name: "singleEvents", value: "true"),
                .init(name: "orderBy", value: "startTime"),
                .init(name: "maxResults", value: "100")
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            var (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 401 {
                // Token may be revoked despite not being expired — force a refresh and retry once.
                let fresh = try await auth.forceRefresh()
                req.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
                (data, resp) = try await URLSession.shared.data(for: req)
            }
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return } // keep last events
            let decoded = try JSONDecoder().decode(GoogleAPIEventsResponse.self, from: data)
            events = GoogleEventMapper.map(decoded.items)
        } catch {
            // Offline / refresh failure: keep last events; auth.state already reflects reauth needs.
        }
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
