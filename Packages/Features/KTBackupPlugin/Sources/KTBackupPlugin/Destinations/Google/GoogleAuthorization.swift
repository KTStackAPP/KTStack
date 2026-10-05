import Foundation

public struct GoogleAuthorizationRequest: Equatable, Sendable {
    public let client: GoogleOAuthClient
    public let redirectURI: String
    public let state: String
    public let pkce: PKCEPair

    public init(client: GoogleOAuthClient, redirectURI: String, state: String, pkce: PKCEPair) {
        self.client = client
        self.redirectURI = redirectURI
        self.state = state
        self.pkce = pkce
    }

    public var url: URL {
        var components = URLComponents(url: GoogleOAuthClient.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = URLEncoding.query([
            ("client_id", client.clientID),
            ("redirect_uri", redirectURI),
            ("response_type", "code"),
            ("scope", GoogleOAuthClient.driveScope),
            ("state", state),
            ("code_challenge", pkce.challenge),
            ("code_challenge_method", "S256"),
            ("access_type", "offline"),
            ("prompt", "consent")
        ])
        return components.url!
    }

    public func authorizationCode(fromCallback target: String) throws -> String {
        guard let components = URLComponents(string: "http://127.0.0.1\(target)") else {
            throw GoogleAuthError.invalidCallback
        }
        let items = Dictionary(
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        guard items["state"] == state else { throw GoogleAuthError.stateMismatch }
        if let error = items["error"] { throw GoogleAuthError.denied(error) }
        guard let code = items["code"], !code.isEmpty else { throw GoogleAuthError.invalidCallback }
        return code
    }
}

public enum GoogleAuthError: Error, LocalizedError, Equatable {
    case invalidCallback
    case stateMismatch
    case denied(String)
    case tokenRejected(String)
    case notConnected
    case listenerFailed(String)
    case clientMissing

    public var errorDescription: String? {
        switch self {
        case .invalidCallback: "Google sent an unexpected sign-in response."
        case .stateMismatch: "The Google sign-in response didn't match this request; try connecting again."
        case let .denied(reason): reason == "access_denied" ? "Google access was denied." : "Google sign-in failed: \(reason)."
        case let .tokenRejected(reason): "Google rejected the sign-in: \(reason). Reconnect Google Drive."
        case .notConnected: "Google Drive isn't connected. Connect the account in Backup Destinations."
        case let .listenerFailed(detail): "Couldn't receive the Google sign-in response: \(detail)"
        case .clientMissing: "No Google OAuth client is configured. Enter your own client ID in the destination form."
        }
    }
}
