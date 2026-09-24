import KTStackCore
import XCTest

final class KTMCPToolCallTests: XCTestCase {
    private var server: FakeIPCServer!

    override func setUpWithError() throws {
        server = try FakeIPCServer { request in
            request.method == "db.backup" ? .fail("not available", id: request.id) : .ok("ok:\(request.method)", id: request.id)
        }
    }

    override func tearDownWithError() throws {
        server.stop()
    }

    private func call(_ json: String) async throws -> KTMCPMessage? {
        let message = try JSONDecoder().decode(KTMCPMessage.self, from: Data(json.utf8))
        return await KTMCPHandler(tools: KTMCPToolCatalog(client: server.client)).handle(message)
    }

    private func isError(_ response: KTMCPMessage?) -> Bool? {
        response?.result?["isError"]?.value as? Bool
    }

    func testToolArgumentsReachTheApp() async throws {
        let response = try await call(
            #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ktstack_restart_service","arguments":{"service":"mysql"}}}"#
        )
        XCTAssertEqual(isError(response), false)
        XCTAssertEqual(server.requests.last?.method, "services.restart")
        XCTAssertEqual(server.requests.last?.params?["service"], "mysql")
    }

    func testLogsToolGoesThroughIPCWithSourceAndLines() async throws {
        _ = try await call(
            #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ktstack_get_recent_logs","arguments":{"source":"mysql","lines":20}}}"#
        )
        XCTAssertEqual(server.requests.last?.method, "logs.recent")
        XCTAssertEqual(server.requests.last?.params?["source"], "mysql")
        XCTAssertEqual(server.requests.last?.params?["lines"], "20")
    }

    func testBackupToolReportsAnErrorInsteadOfSuccess() async throws {
        let response = try await call(
            #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"ktstack_backup_database","arguments":{"database":"shop"}}}"#
        )
        XCTAssertEqual(isError(response), true)
        XCTAssertEqual(server.requests.last?.method, "db.backup")
    }

    func testNotificationsAreNeverAnswered() async throws {
        let response = try await call(#"{"jsonrpc":"2.0","method":"tools/list"}"#)
        XCTAssertNil(response)
    }
}
