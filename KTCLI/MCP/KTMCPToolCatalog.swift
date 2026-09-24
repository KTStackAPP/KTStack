import Foundation
import KTStackCore

public struct KTMCPToolCatalog: Sendable {
    private let client: KTIPCClient

    public init(client: KTIPCClient = KTIPCClient()) {
        self.client = client
    }

    public func listTools() -> [[String: AnyCodable]] {
        [
            tool(
                name: "ktstack_list_sites",
                description: "List all local development sites registered in KTStack with domains, PHP versions, ports, and paths.",
                properties: [:]
            ),
            tool(
                name: "ktstack_get_recent_logs",
                description: "Fetch the last lines of a KTStack log. An unknown source returns the list of available source ids.",
                properties: [
                    "lines": ["type": AnyCodable("integer"), "description": AnyCodable("Number of trailing log lines to fetch (default: 50, max: 2000)")],
                    "source": ["type": AnyCodable("string"), "description": AnyCodable(
                        "Log source id: 'nginx-error' (default), 'nginx-access', 'php-<version>', a service such as 'mysql', "
                            + "'diagnostics', or 'site-<domain>-error' / 'site-<domain>-access'"
                    )]
                ]
            ),
            tool(
                name: "ktstack_list_services",
                description: "List running status of background services (Nginx, MySQL, PostgreSQL, Redis, Mailpit).",
                properties: [:]
            ),
            tool(
                name: "ktstack_restart_service",
                description: "Restart a background service (starts it if it is stopped).",
                properties: [
                    "service": ["type": AnyCodable("string"), "description": AnyCodable("Name of the service (nginx, mysql, postgres, redis, mailpit)")]
                ],
                required: ["service"]
            ),
            tool(
                name: "ktstack_backup_database",
                description: "Database backup from MCP is not available yet; the call returns an error. Use KTStack › Database › Backups.",
                properties: [
                    "database": ["type": AnyCodable("string"), "description": AnyCodable("Name of the database")]
                ],
                required: ["database"]
            ),
            tool(
                name: "ktstack_doctor",
                description: "Run local environment health checks across services, certificates, and DNS.",
                properties: [:]
            )
        ]
    }

    public func callTool(name: String, arguments: [String: AnyCodable]?) async throws -> String {
        switch name {
        case "ktstack_list_sites":
            return try client.call(method: "sites.list")
        case "ktstack_list_services":
            return try client.call(method: "services.list")
        case "ktstack_restart_service":
            guard let service = arguments?["service"]?.value as? String else {
                throw KTCLIError.serverError("Missing required parameter 'service'")
            }
            return try client.call(method: "services.restart", params: ["service": service])
        case "ktstack_get_recent_logs":
            return try client.call(method: "logs.recent", params: logParams(arguments))
        case "ktstack_backup_database":
            let db = arguments?["database"]?.value as? String ?? ""
            return try client.call(method: "db.backup", params: ["database": db])
        case "ktstack_doctor":
            let paths = AppSupportPaths()
            let online = (try? client.call(method: "ping")) != nil
            return "KTStack status: \(online ? "Online" : "Offline"), Path: \(paths.root.path)"
        default:
            throw KTCLIError.serverError("Unknown tool: \(name)")
        }
    }

    private func logParams(_ arguments: [String: AnyCodable]?) -> [String: String] {
        var params: [String: String] = [:]
        if let source = arguments?["source"]?.value as? String { params["source"] = source }
        if let lines = arguments?["lines"]?.value as? Int { params["lines"] = String(lines) }
        if let lines = arguments?["lines"]?.value as? String { params["lines"] = lines }
        return params
    }

    private func tool(
        name: String,
        description: String,
        properties: [String: [String: AnyCodable]],
        required: [String] = []
    ) -> [String: AnyCodable] {
        var schema: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable(properties)
        ]
        if !required.isEmpty {
            schema["required"] = AnyCodable(required)
        }
        return [
            "name": AnyCodable(name),
            "description": AnyCodable(description),
            "inputSchema": AnyCodable(schema)
        ]
    }
}
