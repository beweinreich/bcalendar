import Foundation

final class GoogleAPIClient {
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let auth = GoogleAuthManager.shared

    func request(_ path: String, accountId: String, method: String = "GET",
                 queryItems: [URLQueryItem] = [], body: [String: Any]? = nil) async throws -> Data {
        let token = try await auth.refreshToken(for: accountId)

        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw APIError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        return data
    }

    // MARK: - Calendar List

    func fetchCalendarList(accountId: String) async throws -> [[String: Any]] {
        let data = try await request("/users/me/calendarList", accountId: accountId)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["items"] as? [[String: Any]] ?? []
    }

    // MARK: - Events

    func fetchEvents(accountId: String, calendarId: String, timeMin: Date? = nil,
                     timeMax: Date? = nil, syncToken: String? = nil,
                     pageToken: String? = nil) async throws -> (events: [[String: Any]], nextPageToken: String?, nextSyncToken: String?) {
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "singleEvents", value: "false"))
        queryItems.append(URLQueryItem(name: "maxResults", value: "2500"))

        if let syncToken = syncToken {
            queryItems.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            let fmt = ISO8601DateFormatter()
            if let timeMin = timeMin {
                queryItems.append(URLQueryItem(name: "timeMin", value: fmt.string(from: timeMin)))
            }
            if let timeMax = timeMax {
                queryItems.append(URLQueryItem(name: "timeMax", value: fmt.string(from: timeMax)))
            }
        }

        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        let escapedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let data = try await request("/calendars/\(escapedCalId)/events",
                                      accountId: accountId, queryItems: queryItems)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        return (
            events: json["items"] as? [[String: Any]] ?? [],
            nextPageToken: json["nextPageToken"] as? String,
            nextSyncToken: json["nextSyncToken"] as? String
        )
    }

    func insertEvent(accountId: String, calendarId: String, body: [String: Any]) async throws -> [String: Any] {
        let escapedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let data = try await request("/calendars/\(escapedCalId)/events",
                                      accountId: accountId, method: "POST", body: body)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func updateEvent(accountId: String, calendarId: String, eventId: String,
                     body: [String: Any], sendUpdates: String = "none") async throws -> [String: Any] {
        let escapedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let escapedEvtId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let queryItems = [URLQueryItem(name: "sendUpdates", value: sendUpdates)]
        let data = try await request("/calendars/\(escapedCalId)/events/\(escapedEvtId)",
                                      accountId: accountId, method: "PUT",
                                      queryItems: queryItems, body: body)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func patchEvent(accountId: String, calendarId: String, eventId: String,
                    body: [String: Any], sendUpdates: String = "none") async throws -> [String: Any] {
        let escapedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let escapedEvtId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let queryItems = [URLQueryItem(name: "sendUpdates", value: sendUpdates)]
        let data = try await request("/calendars/\(escapedCalId)/events/\(escapedEvtId)",
                                      accountId: accountId, method: "PATCH",
                                      queryItems: queryItems, body: body)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func deleteEvent(accountId: String, calendarId: String, eventId: String,
                     sendUpdates: String = "none") async throws {
        let escapedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let escapedEvtId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let queryItems = [URLQueryItem(name: "sendUpdates", value: sendUpdates)]
        _ = try await request("/calendars/\(escapedCalId)/events/\(escapedEvtId)",
                               accountId: accountId, method: "DELETE", queryItems: queryItems)
    }
}

enum APIError: Error, LocalizedError {
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        }
    }

    var is410Gone: Bool {
        if case .httpError(410, _) = self { return true }
        return false
    }
}
