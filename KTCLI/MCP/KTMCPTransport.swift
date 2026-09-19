import Foundation

public final class KTMCPTransport: Sendable {
    private let handler: KTMCPHandler

    public init(handler: KTMCPHandler = KTMCPHandler()) {
        self.handler = handler
    }

    public func run() async {
        if isatty(STDIN_FILENO) != 0 {
            fputs("""
            KTStack MCP Server (Model Context Protocol)
            Running on stdio (JSON-RPC 2.0).
            Waiting for AI agent requests (Cursor, Claude Desktop, Claude Code)...

            Configure in your MCP config (e.g. claude_desktop_config.json):
              "ktstack": {
                "command": "kt",
                "args": ["mcp"]
              }
            Press Ctrl+C to exit.

            """, stderr)
        }
        let output = FileHandle.standardOutput

        while true {
            guard let line = readLine() else { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }

            guard let request = try? JSONDecoder().decode(KTMCPMessage.self, from: data) else {
                let err = KTMCPErrorDetail(code: -32700, message: "Parse error")
                let resp = KTMCPMessage(error: err)
                send(resp, to: output)
                continue
            }

            if let response = await handler.handle(request) {
                send(response, to: output)
            }
        }
    }

    private func send(_ message: KTMCPMessage, to output: FileHandle) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        output.write(data)
        output.write(Data([0x0A]))
    }
}
