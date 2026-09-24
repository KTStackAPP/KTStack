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

    func testCreateSiteToolSendsPathAndPHP() async throws {
        let response = try await call(
            #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"ktstack_create_site","arguments":{"path":"/Users/me/Sites/shop","php":"8.4"}}}"#
        )
        XCTAssertEqual(isError(response), false)
        XCTAssertEqual(server.requests.last?.method, "sites.create")
        XCTAssertEqual(server.requests.last?.params?["path"], "/Users/me/Sites/shop")
        XCTAssertEqual(server.requests.last?.params?["php"], "8.4")
    }

    func testSwitchPHPToolRequiresDomainAndVersion() async throws {
        let missing = try await call(
            #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"ktstack_switch_php_version","arguments":{"domain":"shop.test"}}}"#
        )
        XCTAssertEqual(isError(missing), true)
        XCTAssertTrue(server.requests.isEmpty)
        _ = try await call(
            #"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"ktstack_switch_php_version","arguments":{"domain":"shop.test","version":"8.4"}}}"#
        )
        XCTAssertEqual(server.requests.last?.method, "sites.switch_php")
        XCTAssertEqual(server.requests.last?.params?["version"], "8.4")
    }

    func testToolListOffersSiteToolsButNoRestore() {
        let names = KTMCPToolCatalog(client: server.client).listTools().compactMap { $0["name"]?.value as? String }
        XCTAssertTrue(names.contains("ktstack_create_site"))
        XCTAssertTrue(names.contains("ktstack_switch_php_version"))
        XCTAssertFalse(names.contains { $0.contains("restore") })
    }

    func testNotificationsAreNeverAnswered() async throws {
        let response = try await call(#"{"jsonrpc":"2.0","method":"tools/list"}"#)
        XCTAssertNil(response)
    }
}
