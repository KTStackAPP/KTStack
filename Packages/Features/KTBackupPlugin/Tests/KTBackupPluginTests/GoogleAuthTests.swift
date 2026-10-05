import Foundation
import XCTest
@testable import KTBackupPlugin

final class GoogleAuthTests: XCTestCase {
    private let client = GoogleOAuthClient(clientID: "cid.apps.googleusercontent.com", clientSecret: "shh")

    private func request() -> GoogleAuthorizationRequest {
        GoogleAuthorizationRequest(client: client, redirectURI: "http://127.0.0.1:53682/callback", state: "st8",
                                   pkce: PKCEPair(verifier: "dBjftJeZ4CVP-mJ92K9PuGjZ3xnfMh5wCpQGzrpYKEw"))
    }

    func testPKCEChallengeIsBase64URLSHA256OfVerifier() {
        XCTAssertEqual(request().pkce.challenge, "dCgLNyfq3K3dtsb3fODAPOUPNJdnROazWmi6BqNkPfU")
        let random = PKCEPair.random()
        XCTAssertEqual(random.verifier.count, 64)
        XCTAssertFalse(random.verifier.contains("="))
    }

    func testAuthorizationURLRequestsOnlyDriveFileScopeWithOfflineAccess() throws {
        let components = try XCTUnwrap(URLComponents(url: request().url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.host, "accounts.google.com")
        XCTAssertEqual(items["scope"], "https://www.googleapis.com/auth/drive.file")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["access_type"], "offline")
        XCTAssertEqual(items["redirect_uri"], "http://127.0.0.1:53682/callback")
        XCTAssertEqual(items["state"], "st8")
    }

    func testCallbackParsing() throws {
        let request = request()
        XCTAssertEqual(try request.authorizationCode(fromCallback: "/callback?state=st8&code=4%2FabC"), "4/abC")
        XCTAssertThrowsError(try request.authorizationCode(fromCallback: "/callback?state=other&code=x")) {
            XCTAssertEqual($0 as? GoogleAuthError, .stateMismatch)
        }
        XCTAssertThrowsError(try request.authorizationCode(fromCallback: "/callback?state=st8&error=access_denied")) {
            XCTAssertEqual($0 as? GoogleAuthError, .denied("access_denied"))
        }
        XCTAssertThrowsError(try request.authorizationCode(fromCallback: "/callback?state=st8")) {
            XCTAssertEqual($0 as? GoogleAuthError, .invalidCallback)
        }
    }

    func testExchangeSendsVerifierAndParsesTokens() async throws {
        let body = #"{"access_token":"ya29","expires_in":3599,"refresh_token":"1//r","token_type":"Bearer"}"#
        let transport = ScriptedTransport([{ _, _ in HTTPResponse(status: 200, body: Data(body.utf8)) }])
        let now = date("2026-05-10 02:00:00")
        let tokens = try await GoogleTokenClient(client: client, transport: transport, now: { now })
            .exchange(code: "4/abC", request: request())
        XCTAssertEqual(tokens, GoogleTokens(accessToken: "ya29", expiresAt: now.addingTimeInterval(3599), refreshToken: "1//r"))
        guard case let .data(form) = transport.requests[0].1 else { return XCTFail("missing form") }
        let text = String(decoding: form, as: UTF8.self)
        XCTAssertTrue(text.contains("code_verifier=dBjftJeZ4CVP-mJ92K9PuGjZ3xnfMh5wCpQGzrpYKEw"))
        XCTAssertTrue(text.contains("code=4%2FabC"))
        XCTAssertTrue(text.contains("client_secret=shh"))
    }

    func testRefreshKeepsRefreshTokenAndRejectsErrors() async throws {
        let ok = #"{"access_token":"new","expires_in":3600}"#
        let bad = #"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#
        let transport = ScriptedTransport([
            { _, _ in HTTPResponse(status: 200, body: Data(ok.utf8)) },
            { _, _ in HTTPResponse(status: 400, body: Data(bad.utf8)) }
        ])
        let tokenClient = GoogleTokenClient(client: client, transport: transport)
        let refreshed = try await tokenClient.refresh("1//keep")
        XCTAssertEqual(refreshed.refreshToken, "1//keep")
        do {
            _ = try await tokenClient.refresh("1//keep")
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? GoogleAuthError, .tokenRejected("Token has been expired or revoked."))
        }
    }

    func testAccessTokenProviderCachesUntilRefreshMargin() async throws {
        let body = #"{"access_token":"t","expires_in":3600}"#
        let transport = ScriptedTransport([
            { _, _ in HTTPResponse(status: 200, body: Data(body.utf8)) },
            { _, _ in HTTPResponse(status: 200, body: Data(body.utf8)) }
        ])
        let clock = TestClock(date("2026-05-10 02:00:00"))
        let provider = GoogleAccessTokenProvider(
            tokenClient: GoogleTokenClient(client: client, transport: transport, now: { clock.now }),
            loadRefreshToken: { "1//r" }, now: { clock.now }
        )
        _ = try await provider.accessToken()
        _ = try await provider.accessToken()
        XCTAssertEqual(transport.requests.count, 1)
        clock.advance(3600 - 60)
        _ = try await provider.accessToken()
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testMissingRefreshTokenMeansNotConnected() async {
        let provider = GoogleAccessTokenProvider(
            tokenClient: GoogleTokenClient(client: client, transport: ScriptedTransport([])), loadRefreshToken: { nil }
        )
        do {
            _ = try await provider.accessToken()
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? GoogleAuthError, .notConnected)
        }
    }

    func testBundledClientIgnoresUnexpandedBuildSettings() {
        XCTAssertNil(GoogleOAuthClient.bundled([GoogleOAuthClient.bundledClientIDKey: "$(KT_GOOGLE_CLIENT_ID)"]))
        XCTAssertNil(GoogleOAuthClient.bundled([GoogleOAuthClient.bundledClientIDKey: ""]))
        XCTAssertEqual(
            GoogleOAuthClient.bundled([GoogleOAuthClient.bundledClientIDKey: "id", GoogleOAuthClient.bundledClientSecretKey: "$(X)"]),
            GoogleOAuthClient(clientID: "id", clientSecret: nil)
        )
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        locked(lock) { current }
    }

    func advance(_ seconds: TimeInterval) {
        locked(lock) { current = current.addingTimeInterval(seconds) }
    }
}
