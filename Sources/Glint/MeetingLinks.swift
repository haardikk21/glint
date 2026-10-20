import Foundation

enum MeetingLinks {
    private static let hosts = ["meet.google.com", "zoom.us", "zoomgov.com", "teams.microsoft.com", "teams.live.com",
                                "teams.cloud.microsoft", "webex.com", "whereby.com", "chime.aws", "gotomeeting.com",
                                "meet.goto.com", "around.co", "meet.jit.si"]
    // Matches full URLs and scheme-less links such as "meet.google.com/abc-defg-hij" in a location field.
    private static let pattern = try! NSRegularExpression(
        pattern: #"(?:https?://)?(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?:/[^\s<>"']*)?"#
    )

    static func first(in fields: [String?]) -> URL? {
        for field in fields.compactMap({ $0 }) {
            for match in pattern.matches(in: field, range: NSRange(field.startIndex..<field.endIndex, in: field)) {
                guard let range = Range(match.range, in: field) else { continue }
                var raw = String(field[range]).trimmingCharacters(in: CharacterSet(charactersIn: ").,;>"))
                let lower = raw.lowercased()
                if lower.hasPrefix("http://") { continue }
                if !lower.hasPrefix("https://") {
                    // Scheme-less links only count when they carry a path (avoid bare "zoom.us" mentions).
                    guard raw.contains("/") else { continue }
                    raw = "https://" + raw
                }
                guard let url = URL(string: raw), url.scheme == "https", let host = url.host?.lowercased() else {
                    continue
                }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}

enum MeetingWindow {
    /// How long before a meeting's start the join row appears.
    static let lead: TimeInterval = 120

    static func isJoinable(start: Date, end: Date, now: Date) -> Bool {
        start.addingTimeInterval(-lead) <= now && end > now
    }
}
