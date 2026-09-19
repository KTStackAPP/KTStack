import Foundation

public enum ShellToolSuite: String, CaseIterable, Sendable, Identifiable, Hashable {
    case ktstack
    case php
    case node
    case mysql
    case postgres
    case redis

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .ktstack:
            "KTStack CLI & MCP"
        case .php:
            "PHP Suite"
        case .node:
            "Node.js Suite"
        case .mysql:
            "MySQL / MariaDB Tools"
        case .postgres:
            "PostgreSQL Tools"
        case .redis:
            "Redis Tools"
        }
    }

    public var iconName: String {
        switch self {
        case .ktstack:
            "terminal"
        case .php:
            "chevron.left.forwardslash.chevron.right"
        case .node:
            "hexagon"
        case .mysql:
            "cylinder"
        case .postgres:
            "cylinder.split.1x2"
        case .redis:
            "bolt.horizontal"
        }
    }
}
