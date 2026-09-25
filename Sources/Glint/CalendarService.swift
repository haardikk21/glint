import Foundation

@MainActor final class CalendarService: ObservableObject {
    @Published private(set) var meeting: GoogleMeeting?
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var status: String?
    @Published var clientID: String {
        didSet {
            UserDefaults.standard.set(clientID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "googleClientID")
            connected = credentials?.clientID == clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private let oauth = GoogleOAuth()
    private var credentials: GoogleCredentials?
    private var calendarIDs: [String] = []
    private var calendarsLoadedAt = Date.distantPast
    private var timer: Timer?
    private var refreshing = false

    init() {
        clientID = UserDefaults.standard.string(forKey: "googleClientID") ?? ""
        credentials = GoogleKeychain.load()
        connected = credentials != nil && credentials?.clientID == clientID
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func signIn() async {
        guard !connecting else { return }
        connecting = true
        status = nil
        do {
            let credential = try await oauth.signIn(clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines))
            credentials = credential
            connected = true
            calendarIDs = []
            await refresh()
            if status == nil { status = "Connected to Google Calendar" }
        } catch { status = error.localizedDescription }
        connecting = false
    }

    func disconnect() {
        GoogleKeychain.delete()
        credentials = nil
        connected = false
        calendarIDs = []
        meeting = nil
        status = "Google Calendar disconnected"
    }

    func refresh() async {
        guard connected, !refreshing, var credential = credentials else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            credential = try await oauth.accessToken(for: credential)
            credentials = credential
            let now = Date()
            do {
                meeting = try await fetchMeeting(token: credential.accessToken, now: now)
            } catch GoogleCalendarError.unauthorized {
                credential = try await oauth.accessToken(for: credential, forceRefresh: true)
                credentials = credential
                meeting = try await fetchMeeting(token: credential.accessToken, now: now)
            }
            status = nil
        } catch {
            status = error.localizedDescription
            if case GoogleCalendarError.unauthorized = error { meeting = nil }
        }
    }

    private func fetchMeeting(token: String, now: Date) async throws -> GoogleMeeting? {
        if calendarIDs.isEmpty || now.timeIntervalSince(calendarsLoadedAt) > 600 {
            calendarIDs = try await GoogleCalendarAPI.calendarIDs(token: token)
            calendarsLoadedAt = now
        }
        return try await GoogleCalendarAPI.meetings(token: token, calendarIDs: calendarIDs, now: now).first
    }
}
