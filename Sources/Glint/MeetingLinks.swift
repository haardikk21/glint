import Foundation

enum MeetingLinks {
    private static let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com",
                                "webex.com", "whereby.com", "chime.aws"]
    private static let pattern = try! NSRegularExpression(pattern: #"https?://[^\s<>\"']+"#)

    static func first(in fields: [String?]) -> URL? {
        for field in fields.compactMap({ $0 }) {
            for match in pattern.matches(in: field, range: NSRange(field.startIndex..<field.endIndex, in: field)) {
                guard let range = Range(match.range, in: field) else { continue }
                let raw = String(field[range]).trimmingCharacters(in: CharacterSet(charactersIn: ").,;"))
                guard let url = URL(string: raw), url.scheme == "https", let host = url.host?.lowercased() else {
                    continue
                }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}
