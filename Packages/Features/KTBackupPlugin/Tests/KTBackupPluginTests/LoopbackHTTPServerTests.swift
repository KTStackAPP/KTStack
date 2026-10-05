import Foundation
import XCTest
@testable import KTBackupPlugin

final class LoopbackHTTPServerTests: XCTestCase {
    private func fetch(_ url: URL) async throws -> (Int, String) {
        let (data, response) = try await URLSession.shared.data(from: url)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, String(decoding: data, as: UTF8.self))
    }

    func testServesARequestOnLoopback() async throws {
        let server = try LoopbackHTTPServer()
        defer { server.stop() }
        XCTAssertGreaterThan(server.port, 0)
        async let reply = fetch(URL(string: "http://127.0.0.1:\(server.port)/callback?state=a&code=b%2Fc")!)
        let request = try await server.nextRequest(timeout: 5)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "/callback")
        XCTAssertEqual(request.queryItems["code"], "b/c")
        request.respond(status: 200, body: "done")
        let (status, body) = try await reply
        XCTAssertEqual(status, 200)
        XCTAssertEqual(body, "done")
    }

    func testTimesOutWithoutARequest() async throws {
        let server = try LoopbackHTTPServer()
        defer { server.stop() }
        do {
            _ = try await server.nextRequest(timeout: 0.3)
            XCTFail("expected timeout")
        } catch let error as GoogleAuthError {
            guard case .listenerFailed = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testFixedPortThatIsBusyFails() throws {
        let first = try LoopbackHTTPServer()
        defer { first.stop() }
        XCTAssertThrowsError(try LoopbackHTTPServer(port: first.port))
    }

    func testCancellationStopsWaiting() async throws {
        let server = try LoopbackHTTPServer()
        let task = Task { try await server.nextRequest(timeout: 30) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testPickerPageEscapesInjectedValues() {
        let html = GooglePickerPage.html(configuration: GooglePickerConfiguration(apiKey: "k</script>", appID: "123"),
                                         accessToken: "t\"x", nonce: "n")
        XCTAssertFalse(html.contains("k</script>"))
        XCTAssertTrue(html.contains("k\\u003c\\/script\\u003e") || html.contains("k\\u003c/script\\u003e"))
        XCTAssertNil(GooglePickerConfiguration.bundled([GoogleOAuthClient.bundledPickerAPIKey: "$(KEY)"]))
    }
}
