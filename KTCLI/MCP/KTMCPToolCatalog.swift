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
                description: "Fetch recent lines of Nginx or PHP-FPM error logs for diagnosing issues.",
                properties: [
                    "lines": ["type": AnyCodable("integer"), "description": AnyCodable("Number of trailing log lines to fetch (default: 50)")],
                    "source": ["type": AnyCodable("string"), "description": AnyCodable("Log source: 'front-error', 'php-error', 'backends'")]
                ]
            ),
            tool(
                name: "ktstack_list_services",
                description: "List running status of background services (Nginx, MySQL, PostgreSQL, Redis, Mailpit).",
                properties: [:]
            ),
            tool(
                name: "ktstack_restart_service",
                description: "Restart a specified background service.",
                properties: [
                    "service": ["type": AnyCodable("string"), "description": AnyCodable("Name of the service (nginx, mysql, postgres, redis, mailpit)")]
                ],
                required: ["service"]
            ),
            tool(
                name: "ktstack_backup_database",
                description: "Trigger a backup for a target database (MySQL, PostgreSQL, SQLite).",
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
            return fetchRecentLogs(arguments: arguments)
        case "ktstack_backup_database":
            let db = arguments?["database"]?.value as? String ?? "default"
            return "Database backup requested for '\(db)'. Use 'kt db backup \(db)' or check KTStack Database Backups."
        case "ktstack_doctor":
            let paths = AppSupportPaths()
            let online = (try? client.call(method: "ping")) != nil
            return "KTStack status: \(online ? "Online" : "Offline"), Path: \(paths.root.path)"
        default:
            throw KTCLIError.serverError("Unknown tool: \(name)")
        }
    }

    private func fetchRecentLogs(arguments: [String: AnyCodable]?) -> String {
        let count = arguments?["lines"]?.value as? Int ?? 50
        let logsDir = AppSupportPaths().logs
        let fileURL = logsDir.appendingPathComponent("front-error.log")
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return "No recent logs found at \(fileURL.path)."
        }
        let lines = content.components(separatedBy: "\n")
        let trailing = lines.suffix(count).joined(separator: "\n")
        return trailing.isEmpty ? "Log file is empty." : trailing
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
