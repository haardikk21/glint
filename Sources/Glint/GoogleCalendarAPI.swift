import Foundation

enum GoogleCalendarAPI {
    static func calendarIDs(token: String) async throws -> [String] {
        var ids: [String] = []
        var page: String?
        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
            components.queryItems = [URLQueryItem(name: "maxResults", value: "250")]
            if let page { components.queryItems?.append(URLQueryItem(name: "pageToken", value: page)) }
            let result: GoogleCalendarModels.CalendarList = try await get(components.url!, token: token)
            ids += (result.items ?? []).filter { $0.selected != false && $0.accessRole != "freeBusyReader" }.map(\.id)
            page = result.nextPageToken
        } while page != nil && ids.count < 50
        return Array(ids.prefix(50))
    }

    static func meetings(token: String, calendarIDs: [String], now: Date) async throws -> [GoogleMeeting] {
        try await withThrowingTaskGroup(of: [GoogleMeeting].self) { group in
            for id in calendarIDs {
                group.addTask { try await events(token: token, calendarID: id, now: now) }
            }
            var meetings: [GoogleMeeting] = []
            for try await batch in group { meetings += batch }
            return meetings.sorted { $0.start < $1.start }
        }
    }

    private static func events(token: String, calendarID: String, now: Date) async throws -> [GoogleMeeting] {
        let encodedID = calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))!
        let endpoint = "https://www.googleapis.com/calendar/v3/calendars/\(encodedID)/events"
        var meetings: [GoogleMeeting] = []
        var page: String?
        repeat {
            var components = URLComponents(string: endpoint)!
            components.queryItems = [
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "maxResults", value: "100"),
                URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: now)),
                URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: now.addingTimeInterval(121)))
            ]
            if let page { components.queryItems?.append(URLQueryItem(name: "pageToken", value: page)) }
            let result: GoogleCalendarModels.EventList = try await get(components.url!, token: token)
            meetings += (result.items ?? []).compactMap { GoogleCalendarModels.meeting(from: $0, now: now) }
            page = result.nextPageToken
        } while page != nil && meetings.count < 100
        return meetings
    }

    private static func get<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw GoogleCalendarError.response }
        if response.statusCode == 401 { throw GoogleCalendarError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            throw GoogleCalendarError.http(response.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum GoogleCalendarError: LocalizedError {
    case response, unauthorized, http(Int), missingClientID, noRefreshToken, signInTimedOut, invalidCallback, missingScope

    var errorDescription: String? {
        switch self {
        case .response: "Google returned an invalid response."
        case .unauthorized: "Google session expired. Reconnect your account."
        case .http(let status): "Google Calendar request failed (HTTP \(status))."
        case .missingClientID: "Enter a Google OAuth Desktop client ID first."
        case .noRefreshToken: "Google did not return a refresh token. Reconnect your account."
        case .signInTimedOut: "Google sign-in timed out. Try again."
        case .invalidCallback: "Could not complete Google sign-in."
        case .missingScope: "Calendar read access was not granted."
        }
    }
}
