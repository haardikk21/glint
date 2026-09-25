import Foundation

struct GoogleMeeting: Equatable {
    let title: String
    let start: Date
    let url: URL
}

enum GoogleCalendarModels {
    struct CalendarList: Decodable {
        let items: [Calendar]?
        let nextPageToken: String?
    }

    struct Calendar: Decodable {
        let id: String
        let selected: Bool?
        let accessRole: String?
    }

    struct EventList: Decodable {
        let items: [Event]?
        let nextPageToken: String?
    }

    struct Event: Decodable {
        let summary: String?
        let description: String?
        let location: String?
        let hangoutLink: String?
        let start: EventTime?
        let end: EventTime?
        let status: String?
        let conferenceData: Conference?
        let attendees: [Attendee]?
    }

    struct EventTime: Decodable { let dateTime: String? }
    struct Conference: Decodable { let entryPoints: [EntryPoint]? }
    struct EntryPoint: Decodable { let entryPointType: String?; let uri: String? }
    struct Attendee: Decodable { let `self`: Bool?; let responseStatus: String? }

    static func meeting(from event: Event, now: Date) -> GoogleMeeting? {
        guard event.status != "cancelled",
              event.attendees?.contains(where: { $0.`self` == true && $0.responseStatus == "declined" }) != true,
              let startText = event.start?.dateTime, let endText = event.end?.dateTime,
              let start = date(startText), let end = date(endText),
              end > now, start <= now.addingTimeInterval(120) else { return nil }
        let candidates = (event.conferenceData?.entryPoints ?? [])
            .filter { $0.entryPointType == "video" }.compactMap(\.uri)
            + [event.hangoutLink, event.location, event.description].compactMap { $0 }
        for candidate in candidates {
            if let url = joinURL(in: candidate) {
                return GoogleMeeting(title: event.summary ?? "Meeting", start: start, url: url)
            }
        }
        return nil
    }

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private static func joinURL(in text: String) -> URL? {
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com",
                     "webex.com", "whereby.com", "chime.aws"]
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>\"']+"#) else { return nil }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let raw = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ").,;"))
            guard let url = URL(string: raw), url.scheme == "https", let host = url.host?.lowercased() else { continue }
            if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
        }
        return nil
    }
}
