import Foundation
import EventKit
import CoreGraphics

/// The only type that touches EventKit. Reads events for a rolling window and
/// publishes plain `CalendarEventInfo` values. Read-only, local, no network.
@MainActor
final class CalendarService: ObservableObject {
    enum Access { case notDetermined, denied, authorized }

    @Published private(set) var access: Access
    @Published private(set) var events: [CalendarEventInfo] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                Task { await requestAccess() }
            } else {
                events = []
            }
        }
    }

    var isActive: Bool { isEnabled && access == .authorized }

    private static let enabledKey = "calendarEnabled"
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.access = Self.map(EKEventStore.authorizationStatus(for: .event))
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if isActive { refresh() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    static func map(_ status: EKAuthorizationStatus) -> Access {
        switch status {
        case .fullAccess, .authorized: return .authorized
        case .denied, .restricted, .writeOnly: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .authorized : .denied
            if isActive { refresh() }
        } catch {
            access = .denied
        }
    }

    func refresh() {
        guard isActive else { events = []; return }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(48 * 3600),
            calendars: nil
        )
        events = store.events(matching: predicate)
            .compactMap { ek -> CalendarEventInfo? in
                guard let start = ek.startDate, let end = ek.endDate else { return nil }
                let rawTitle = ek.title ?? ""
                return CalendarEventInfo(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: rawTitle.isEmpty ? "(No title)" : rawTitle,
                    start: start,
                    end: end,
                    isAllDay: ek.isAllDay,
                    calendarColorHex: Self.hex(ek.calendar?.cgColor),
                    location: ek.location,
                    url: ek.url
                        ?? ek.location.flatMap(CalendarLogic.firstURL(in:))
                        ?? ek.notes.flatMap(CalendarLogic.firstURL(in:))
                )
            }
            .sorted { $0.start < $1.start }
    }

    private static func hex(_ color: CGColor?) -> String? {
        guard let comps = color?.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
