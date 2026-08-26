import Foundation

struct APIRequestSpec: Sendable {
    var method: String
    var url: URL
    var headers: [(String, String)]
    var body: Data?
}

struct APIResponseResult: Sendable {
    let statusCode: Int
    let headers: [(String, String)]
    let body: Data
    let elapsedMs: Int
    let contentType: String?
}

struct APIRequestClient: Sendable {
    struct RequestError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let session: URLSession

    init(timeout: TimeInterval = 30) {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: cfg)
    }

    func send(_ spec: APIRequestSpec) async throws -> APIResponseResult {
        var request = URLRequest(url: spec.url)
        request.httpMethod = spec.method
        for (key, value) in spec.headers where !key.isEmpty {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = spec.body

        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else {
                throw RequestError(message: "The server returned a non-HTTP response.")
            }
            return APIResponseResult(
                statusCode: http.statusCode,
                headers: Self.headerPairs(http),
                body: data,
                elapsedMs: elapsed,
                contentType: http.value(forHTTPHeaderField: "Content-Type")
            )
        } catch let error as URLError {
            throw RequestError(message: Self.message(for: error))
        }
    }

    private static func headerPairs(_ http: HTTPURLResponse) -> [(String, String)] {
        http.allHeaderFields
            .compactMap { key, value in
                guard let name = key as? String else { return nil }
                return (name, String(describing: value))
            }
            .sorted { $0.0.lowercased() < $1.0.lowercased() }
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .timedOut:
            "Request timed out. Increase the timeout or check the site is responding."
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            "Could not reach the site. Check that the service is running."
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid:
            "TLS handshake failed. Ensure the local CA is trusted for this site."
        default:
            error.localizedDescription
        }
    }
}
