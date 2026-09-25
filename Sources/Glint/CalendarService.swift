import EventKit
import Foundation
import Security

struct CalendarMeeting: Equatable {
    let title: String
    let start: Date
    let url: URL
}

@MainActor final class CalendarService: ObservableObject {
    @Published private(set) var meeting: CalendarMeeting?
    @Published private(set) var authorized: Bool
    @Published private(set) var status: String?

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        Self.removeLegacyGoogleCredentials()
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestAccess() async {
        do {
            authorized = try await store.requestFullAccessToEvents()
            status = authorized ? nil : "Enable Glint in System Settings → Privacy & Security → Calendars."
        } catch { status = error.localizedDescription }
        refresh()
    }

    func refresh() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard authorized else { meeting = nil; return }
        status = nil
        let now = Date()
        let events = store.events(matching: store.predicateForEvents(
            withStart: now.addingTimeInterval(-24 * 60 * 60), end: now.addingTimeInterval(121),
            calendars: nil
        ))
        let upcoming = events.filter {
            !$0.isAllDay && $0.status != .canceled && $0.endDate > now &&
                $0.startDate <= now.addingTimeInterval(120)
        }.sorted { $0.startDate < $1.startDate }
            .compactMap { event -> CalendarMeeting? in
                guard let url = MeetingLinks.first(in: [event.url?.absoluteString, event.location, event.notes]) else {
                    return nil
                }
                return CalendarMeeting(title: event.title ?? "Meeting", start: event.startDate, url: url)
            }.first
        if meeting != upcoming { meeting = upcoming }
    }

    private static func removeLegacyGoogleCredentials() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "removedLegacyGoogleCalendar") else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "dev.haardik.glint.google-calendar",
                                    kSecAttrAccount as String: "oauth"]
        let result = SecItemDelete(query as CFDictionary)
        if result == errSecSuccess || result == errSecItemNotFound {
            defaults.removeObject(forKey: "googleClientID")
            defaults.set(true, forKey: "removedLegacyGoogleCalendar")
        }
    }
}
