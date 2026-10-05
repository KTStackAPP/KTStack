import Foundation

public struct GoogleSignInResult: Equatable, Sendable {
    public var refreshToken: String
    public var accountEmail: String
}

public struct GoogleSignInFlow: Sendable {
    public static let callbackPath = "/callback"

    let client: GoogleOAuthClient
    let transport: any HTTPTransport
    let openURL: @Sendable (URL) -> Void
    let timeout: TimeInterval

    public init(client: GoogleOAuthClient, transport: any HTTPTransport, timeout: TimeInterval = 300,
                openURL: @escaping @Sendable (URL) -> Void) {
        self.client = client
        self.transport = transport
        self.timeout = timeout
        self.openURL = openURL
    }

    public func run() async throws -> GoogleSignInResult {
        let server = try LoopbackHTTPServer()
        defer { server.stop() }
        let request = GoogleAuthorizationRequest(
            client: client,
            redirectURI: "http://127.0.0.1:\(server.port)\(Self.callbackPath)",
            state: PKCEPair.randomToken(byteCount: 24),
            pkce: .random()
        )
        openURL(request.url)
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let incoming = try await server.nextRequest(timeout: deadline.timeIntervalSinceNow)
            guard incoming.path == Self.callbackPath else {
                incoming.respond(status: 404, body: "")
                continue
            }
            let code: String
            do {
                code = try request.authorizationCode(fromCallback: incoming.target)
            } catch {
                incoming.respond(status: 400, body: LoopbackPages.message("Google Drive wasn't connected", error.localizedDescription))
                throw error
            }
            incoming.respond(status: 200, body: LoopbackPages.message("Google Drive connected", "You can close this tab and return to KTStack."))
            return try await complete(code: code, request: request)
        }
    }

    func complete(code: String, request: GoogleAuthorizationRequest) async throws -> GoogleSignInResult {
        let tokenClient = GoogleTokenClient(client: client, transport: transport)
        let tokens = try await tokenClient.exchange(code: code, request: request)
        guard let refreshToken = tokens.refreshToken else {
            throw GoogleAuthError.tokenRejected("Google didn't return a refresh token")
        }
        let provider = GoogleAccessTokenProvider(tokenClient: tokenClient, loadRefreshToken: { refreshToken }, initial: tokens)
        let email = try await GoogleDriveClient(folderID: "", tokens: provider, transport: transport).accountEmail()
        return GoogleSignInResult(refreshToken: refreshToken, accountEmail: email)
    }
}

enum LoopbackPages {
    static func message(_ title: String, _ detail: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><title>KTStack</title>
        <style>body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;margin:64px auto;max-width:480px;color:#1d1d1f}
        @media(prefers-color-scheme:dark){body{background:#1e1e1e;color:#f5f5f7}}h1{font-size:20px}</style></head>
        <body><h1>\(escape(title))</h1><p>\(escape(detail))</p></body></html>
        """
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
