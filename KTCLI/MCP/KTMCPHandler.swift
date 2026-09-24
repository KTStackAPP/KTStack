import Foundation

public final class KTMCPHandler: Sendable {
    private let tools: KTMCPToolCatalog

    public init(tools: KTMCPToolCatalog = KTMCPToolCatalog()) {
        self.tools = tools
    }

    public func handle(_ message: KTMCPMessage) async -> KTMCPMessage? {
        let response = await respond(to: message)
        return message.id == nil ? nil : response
    }

    private func respond(to message: KTMCPMessage) async -> KTMCPMessage? {
        guard let method = message.method else { return nil }

        switch method {
        case "initialize":
            let capabilities: [String: AnyCodable] = [
                "tools": AnyCodable(["listChanged": false])
            ]
            let serverInfo: [String: AnyCodable] = [
                "name": AnyCodable("ktstack-mcp"),
                "version": AnyCodable(CLIVersion.current())
            ]
            let result: [String: AnyCodable] = [
                "protocolVersion": AnyCodable("2024-11-05"),
                "capabilities": AnyCodable(capabilities),
                "serverInfo": AnyCodable(serverInfo)
            ]
            return KTMCPMessage(id: message.id, result: result)

        case "notifications/initialized":
            return nil

        case "tools/list":
            let toolList = tools.listTools()
            let result: [String: AnyCodable] = [
                "tools": AnyCodable(toolList)
            ]
            return KTMCPMessage(id: message.id, result: result)

        case "tools/call":
            guard let name = message.params?["name"]?.value as? String else {
                let err = KTMCPErrorDetail(code: -32602, message: "Missing tool name")
                return KTMCPMessage(id: message.id, error: err)
            }
            let args = (message.params?["arguments"]?.value as? [String: Any])?.mapValues { AnyCodable($0) }
            do {
                let output = try await tools.callTool(name: name, arguments: args)
                let content: [[String: AnyCodable]] = [
                    ["type": AnyCodable("text"), "text": AnyCodable(output)]
                ]
                let result: [String: AnyCodable] = [
                    "content": AnyCodable(content),
                    "isError": AnyCodable(false)
                ]
                return KTMCPMessage(id: message.id, result: result)
            } catch {
                let content: [[String: AnyCodable]] = [
                    ["type": AnyCodable("text"), "text": AnyCodable(error.localizedDescription)]
                ]
                let result: [String: AnyCodable] = [
                    "content": AnyCodable(content),
                    "isError": AnyCodable(true)
                ]
                return KTMCPMessage(id: message.id, result: result)
            }

        default:
            let err = KTMCPErrorDetail(code: -32601, message: "Method not found: \(method)")
            return KTMCPMessage(id: message.id, error: err)
        }
    }
}
