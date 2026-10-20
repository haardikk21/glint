import AppKit
import EventKit
import Foundation
import Security

struct CalendarMeeting: Equatable {
    let id: String
    let title: String
    let start: Date
    let url: URL
}

@MainActor final class CalendarService: ObservableObject {
    @Published private(set) var meetings: [CalendarMeeting] = []
    @Published private(set) var authorized: Bool
    @Published private(set) var status: String?

    /// True when Glint had calendar access before but no longer does (for example after an
    /// ad-hoc re-sign changed the app's code signature and macOS dropped the grant).
    var accessLost: Bool { !authorized && UserDefaults.standard.bool(forKey: Self.wasAuthorizedKey) }
    var canRequestAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .notDetermined }

    private static let wasAuthorizedKey = "calendarWasAuthorized"
    private var store = EKEventStore()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        Self.removeLegacyGoogleCredentials()
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 3
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(syncSources: true) }
        })
    }

    func requestAccess() async {
        do {
            authorized = try await store.requestFullAccessToEvents()
            status = authorized ? nil : "Enable Glint in System Settings → Privacy & Security → Calendars."
        } catch { status = error.localizedDescription }
        // A store created before access was granted can keep returning no events.
        if authorized { store = EKEventStore() }
        refresh()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh(syncSources: Bool = false) {
        let nowAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        if nowAuthorized && !authorized { store = EKEventStore() }
        if authorized != nowAuthorized { authorized = nowAuthorized }
        guard authorized else {
            if !meetings.isEmpty { meetings = [] }
            return
        }
        UserDefaults.standard.set(true, forKey: Self.wasAuthorizedKey)
        if status != nil { status = nil }
        if syncSources { store.refreshSourcesIfNecessary() }
        let now = Date()
        let events = store.events(matching: store.predicateForEvents(
            withStart: now.addingTimeInterval(-24 * 60 * 60), end: now.addingTimeInterval(MeetingWindow.lead + 1),
            calendars: nil
        ))
        let current = events.filter { event in
            guard !event.isAllDay, event.status != .canceled,
                  MeetingWindow.isJoinable(start: event.startDate, end: event.endDate, now: now) else { return false }
            let me = event.attendees?.first(where: \.isCurrentUser)
            return me?.participantStatus != .declined
        }
        // Soonest/most recently started first.
        .sorted { abs($0.startDate.timeIntervalSince(now)) < abs($1.startDate.timeIntervalSince(now)) }
        .compactMap { event -> CalendarMeeting? in
            guard let url = MeetingLinks.first(in: [event.url?.absoluteString, event.location,
                                                    event.structuredLocation?.title, event.notes]) else {
                return nil
            }
            return CalendarMeeting(id: event.calendarItemIdentifier + "@\(event.startDate.timeIntervalSince1970)",
                                   title: event.title ?? "Meeting", start: event.startDate, url: url)
        }
        let unique = current.reduce(into: [CalendarMeeting]()) { list, meeting in
            if !list.contains(where: { $0.url == meeting.url }) { list.append(meeting) }
        }
        let next = Array(unique.prefix(3))
        if meetings != next { meetings = next }
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
