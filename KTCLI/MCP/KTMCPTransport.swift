import Foundation

public final class KTMCPTransport: Sendable {
    private let handler: KTMCPHandler

    public init(handler: KTMCPHandler = KTMCPHandler()) {
        self.handler = handler
    }

    public func run() async {
        let input = FileHandle.standardInput
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
