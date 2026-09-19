import Foundation
import KTStackCore

public struct ShellToolCatalog: Sendable {
    public static let tools: [ShellTool] = [
        ShellTool(id: "kt", command: "kt", displayName: "Developer CLI & MCP Server", suite: .ktstack),
        ShellTool(id: "php", command: "php", displayName: "PHP CLI", suite: .php, isDynamic: true),
        ShellTool(id: "composer", command: "composer", displayName: "Composer", suite: .php, isDynamic: true),
        ShellTool(id: "wp", command: "wp", displayName: "WP-CLI", suite: .php, isDynamic: true),
        ShellTool(id: "node", command: "node", displayName: "Node.js", suite: .node, isDynamic: true),
        ShellTool(id: "npm", command: "npm", displayName: "npm", suite: .node, isDynamic: true),
        ShellTool(id: "npx", command: "npx", displayName: "npx", suite: .node, isDynamic: true),
        ShellTool(id: "mysql", command: "mysql", displayName: "MySQL Client", suite: .mysql),
        ShellTool(id: "mysqldump", command: "mysqldump", displayName: "MySQL Dump", suite: .mysql),
        ShellTool(id: "mysqladmin", command: "mysqladmin", displayName: "MySQL Admin", suite: .mysql),
        ShellTool(id: "psql", command: "psql", displayName: "PostgreSQL Client", suite: .postgres),
        ShellTool(id: "pg_dump", command: "pg_dump", displayName: "PostgreSQL Dump", suite: .postgres),
        ShellTool(id: "createdb", command: "createdb", displayName: "PostgreSQL Create DB", suite: .postgres),
        ShellTool(id: "dropdb", command: "dropdb", displayName: "PostgreSQL Drop DB", suite: .postgres),
        ShellTool(id: "redis-cli", command: "redis-cli", displayName: "Redis CLI", suite: .redis),
        ShellTool(id: "redis-benchmark", command: "redis-benchmark", displayName: "Redis Benchmark", suite: .redis)
    ]

    public static func tools(for suite: ShellToolSuite) -> [ShellTool] {
        tools.filter { $0.suite == suite }
    }

    public static func tool(for command: String) -> ShellTool? {
        tools.first { $0.command == command || $0.id == command }
    }
}
