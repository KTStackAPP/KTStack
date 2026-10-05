import Foundation

public actor GoogleAccessTokenProvider {
    static let refreshMargin: TimeInterval = 120

    private let tokenClient: GoogleTokenClient
    private let loadRefreshToken: @Sendable () throws -> String?
    private let now: @Sendable () -> Date
    private var cached: GoogleTokens?

    public init(tokenClient: GoogleTokenClient, loadRefreshToken: @escaping @Sendable () throws -> String?,
                now: @escaping @Sendable () -> Date = { Date() }, initial: GoogleTokens? = nil) {
        self.tokenClient = tokenClient
        cached = initial
        self.loadRefreshToken = loadRefreshToken
        self.now = now
    }

    public func accessToken() async throws -> String {
        if let cached, cached.expiresAt.timeIntervalSince(now()) > Self.refreshMargin {
            return cached.accessToken
        }
        return try await refresh()
    }

    public func invalidate() {
        cached = nil
    }

    private func refresh() async throws -> String {
        guard let refreshToken = try loadRefreshToken(), !refreshToken.isEmpty else {
            throw GoogleAuthError.notConnected
        }
        let tokens = try await tokenClient.refresh(refreshToken)
        cached = tokens
        return tokens.accessToken
    }
}
