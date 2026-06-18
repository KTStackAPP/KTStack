import Foundation

public struct DumpEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let file: String
    public let line: Int
    public let root: DumpNode

    public init(id: UUID = UUID(), timestamp: Date, file: String, line: Int, root: DumpNode) {
        self.id = id
        self.timestamp = timestamp
        self.file = file
        self.line = line
        self.root = root
    }

    public var sourceDisplay: String {
        "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
    }
}
