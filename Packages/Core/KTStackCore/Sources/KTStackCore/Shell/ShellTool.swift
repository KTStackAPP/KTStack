import Foundation

public struct ShellTool: Sendable, Identifiable, Hashable {
    public let id: String
    public let command: String
    public let displayName: String
    public let suite: ShellToolSuite
    public let isDynamic: Bool

    public init(
        id: String,
        command: String,
        displayName: String,
        suite: ShellToolSuite,
        isDynamic: Bool = false
    ) {
        self.id = id
        self.command = command
        self.displayName = displayName
        self.suite = suite
        self.isDynamic = isDynamic
    }
}
