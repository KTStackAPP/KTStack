import KTStackCore
import XCTest

final class KTMCPHandlerTests: XCTestCase {
    private func handler() -> KTMCPHandler {
        let offline = KTIPCClient(socketPath: "/tmp/ktstack-cli-tests-\(UUID().uuidString).sock")
        return KTMCPHandler(tools: KTMCPToolCatalog(client: offline))
    }

    private func decode(_ json: String) throws -> KTMCPMessage {
        try JSONDecoder().decode(KTMCPMessage.self, from: Data(json.utf8))
    }

    func testInitializeEchoesIdAndProtocolVersion() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#)
        let response = await handler().handle(request)
        XCTAssertEqual(response?.id, .number(1))
        XCTAssertEqual(response?.result?["protocolVersion"]?.value as? String, "2024-11-05")
        XCTAssertNil(response?.error)
    }

    func testToolsListNamesEveryTool() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","id":"a","method":"tools/list"}"#)
        let response = await handler().handle(request)
        let tools = response?.result?["tools"]?.value as? [[String: AnyCodable]] ?? []
        let names = tools.compactMap { $0["name"]?.value as? String }
        XCTAssertTrue(names.contains("ktstack_list_sites"))
        XCTAssertTrue(names.contains("ktstack_list_services"))
        XCTAssertEqual(names.count, Set(names).count)
    }

    func testUnknownMethodReturnsMethodNotFound() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","id":7,"method":"nope"}"#)
        let response = await handler().handle(request)
        XCTAssertEqual(response?.error?.code, -32601)
    }

    func testInitializedNotificationGetsNoReply() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
        let response = await handler().handle(request)
        XCTAssertNil(response)
    }

    func testToolCallWithoutNameIsInvalidParams() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{}}"#)
        let response = await handler().handle(request)
        XCTAssertEqual(response?.error?.code, -32602)
    }

    func testToolCallSurfacesOfflineAppAsToolError() async throws {
        let request = try decode(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"ktstack_list_sites"}}"#)
        let response = await handler().handle(request)
        XCTAssertEqual(response?.result?["isError"]?.value as? Bool, true)
    }
}
