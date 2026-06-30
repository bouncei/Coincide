import Foundation
import Combine

/// Owns the concrete calendar sources and publishes a single merged event list.
@MainActor
final class CalendarHub: ObservableObject {
    let eventKit: CalendarService
    let google: GoogleCalendarService

    @Published private(set) var events: [CalendarEventInfo] = []

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let auth = GoogleAuth()
        self.eventKit = CalendarService()
        self.google = GoogleCalendarService(auth: auth)
        recompute()
        // Re-merge and re-publish whenever either source changes.
        eventKit.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.recompute() } }
            .store(in: &cancellables)
        // NB: `@Published.$events` fires in willSet (before `google.events` is
        // updated), so defer the recompute a tick — otherwise it re-reads the
        // OLD (empty) value and the merged list never picks up Google events.
        google.$events
            .sink { [weak self] _ in DispatchQueue.main.async { self?.recompute() } }
            .store(in: &cancellables)
        google.auth.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.recompute(); self?.objectWillChange.send() } }
            .store(in: &cancellables)
    }

    var isActive: Bool { eventKit.isActive || google.isActive }

    private func recompute() {
        events = CalendarLogic.mergeSorted([eventKit.events, google.events])
    }
}
