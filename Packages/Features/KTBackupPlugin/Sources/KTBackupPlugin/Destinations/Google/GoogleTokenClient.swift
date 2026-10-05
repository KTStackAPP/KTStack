import Foundation

public struct GoogleTokens: Equatable, Sendable {
    public var accessToken: String
    public var expiresAt: Date
    public var refreshToken: String?
}

public struct GoogleTokenClient: Sendable {
    let client: GoogleOAuthClient
    let transport: any HTTPTransport
    let now: @Sendable () -> Date

    public init(client: GoogleOAuthClient, transport: any HTTPTransport, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.transport = transport
        self.now = now
    }

    public func exchange(code: String, request: GoogleAuthorizationRequest) async throws -> GoogleTokens {
        try await post([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", request.redirectURI),
            ("code_verifier", request.pkce.verifier)
        ])
    }

    public func refresh(_ refreshToken: String) async throws -> GoogleTokens {
        var tokens = try await post([("grant_type", "refresh_token"), ("refresh_token", refreshToken)])
        if tokens.refreshToken == nil { tokens.refreshToken = refreshToken }
        return tokens
    }

    public func revoke(_ token: String) async {
        let spec = HTTPRequestSpec(method: "POST", url: GoogleOAuthClient.revocationEndpoint,
                                   headers: ["Content-Type": "application/x-www-form-urlencoded"])
        _ = try? await transport.send(spec, body: .data(URLEncoding.form([("token", token)])))
    }

    private func post(_ fields: [(String, String)]) async throws -> GoogleTokens {
        var form = fields + [("client_id", client.clientID)]
        if let secret = client.clientSecret { form.append(("client_secret", secret)) }
        let spec = HTTPRequestSpec(method: "POST", url: GoogleOAuthClient.tokenEndpoint,
                                   headers: ["Content-Type": "application/x-www-form-urlencoded"])
        let response = try await transport.send(spec, body: .data(URLEncoding.form(form)))
        return try Self.parse(response, now: now())
    }

    static func parse(_ response: HTTPResponse, now: Date) throws -> GoogleTokens {
        let json = (try? JSONSerialization.jsonObject(with: response.body)) as? [String: Any] ?? [:]
        guard response.isSuccess, let access = json["access_token"] as? String else {
            let reason = (json["error_description"] as? String) ?? (json["error"] as? String) ?? "HTTP \(response.status)"
            throw GoogleAuthError.tokenRejected(reason)
        }
        let lifetime = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return GoogleTokens(accessToken: access, expiresAt: now.addingTimeInterval(lifetime),
                            refreshToken: json["refresh_token"] as? String)
    }
}
