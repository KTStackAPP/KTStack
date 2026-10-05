import Foundation

extension GoogleDriveClient {
    static let maxAttempts = 5
    static let rateLimitReasons: Set<String> = ["rateLimitExceeded", "userRateLimitExceeded"]

    func authorized(_ perform: (String) async throws -> HTTPResponse) async throws -> HTTPResponse {
        var attempt = 0
        var refreshed = false
        while true {
            let response = try await perform(try await tokens.accessToken())
            if response.status == 401, !refreshed {
                await tokens.invalidate()
                refreshed = true
                continue
            }
            guard Self.isRetryable(response), attempt < Self.maxAttempts - 1 else { return response }
            attempt += 1
            try await backoff(attempt)
        }
    }

    func backoff(_ attempt: Int) async throws {
        guard retryBaseDelay > 0 else { return }
        try await Task.sleep(nanoseconds: retryBaseDelay << UInt64(max(0, attempt - 1)))
    }

    func send(_ method: String, _ base: String, query: [(String, String)] = [], headers: [String: String] = [:],
              body: HTTPBody = .empty) async throws -> HTTPResponse {
        let text = query.isEmpty ? base : "\(base)?\(URLEncoding.query(query))"
        guard let url = URL(string: text) else { throw BackupDestinationError.remote("Invalid Google Drive URL.") }
        return try await authorized { token in
            var allHeaders = headers
            allHeaders["Authorization"] = "Bearer \(token)"
            return try await transport.send(HTTPRequestSpec(method: method, url: url, headers: allHeaders), body: body)
        }
    }

    func json<T: Decodable>(_ method: String, _ base: String, query: [(String, String)] = [],
                            body: [String: Any]? = nil) async throws -> T {
        var headers: [String: String] = [:]
        var payload = HTTPBody.empty
        if let body {
            headers["Content-Type"] = "application/json; charset=UTF-8"
            payload = .data(try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
        }
        let response = try await send(method, base, query: query, headers: headers, body: payload)
        guard response.isSuccess else { throw Self.error(response) }
        do {
            return try JSONDecoder().decode(T.self, from: response.body)
        } catch {
            throw BackupDestinationError.remote("Google Drive returned an unexpected response.")
        }
    }

    static func isRetryable(_ response: HTTPResponse) -> Bool {
        if response.status == 429 || (500...599).contains(response.status) { return true }
        guard response.status == 403 else { return false }
        let reasons = (try? JSONDecoder().decode(DriveErrorEnvelope.self, from: response.body))?.error.errors?.compactMap(\.reason) ?? []
        return reasons.contains { rateLimitReasons.contains($0) }
    }

    static func error(_ response: HTTPResponse) -> BackupDestinationError {
        let message = (try? JSONDecoder().decode(DriveErrorEnvelope.self, from: response.body))?.error.message
        switch response.status {
        case 401:
            return .missingCredentials("Google rejected the saved sign-in. Reconnect Google Drive.")
        case 404:
            return .remote("Not found (HTTP 404).")
        case 403 where isRetryable(response):
            return .remote("Google Drive rate limit reached; try again later.")
        default:
            return .remote("Google Drive request failed (HTTP \(response.status))\(message.map { ": \($0)" } ?? "").")
        }
    }
}
