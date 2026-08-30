import Foundation

enum SiteEnvError: Error, LocalizedError, Equatable {
    case fileMissing
    case noDatabaseKeys

    var errorDescription: String? {
        switch self {
        case .fileMissing: "This site has no .env file in its project folder."
        case .noDatabaseKeys: "The .env file has no DB_ keys to read."
        }
    }
}

/// Đọc DB_* trong <site>/.env (Laravel style) thành draft kết nối.
enum SiteEnvReader {
    static func read(at path: String) throws -> ConnectionDraft {
        let url = URL(fileURLWithPath: path).appendingPathComponent(".env")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SiteEnvError.fileMissing
        }
        let env = parse(text)
        guard env.keys.contains(where: { $0.hasPrefix("DB_") }) else {
            throw SiteEnvError.noDatabaseKeys
        }

        let kind = kind(for: env["DB_CONNECTION"])
        let host = env["DB_HOST"].flatMap { $0.isEmpty ? nil : $0 } ?? "127.0.0.1"
        let port = env["DB_PORT"].flatMap(Int.init) ?? kind.defaultPort
        let database = env["DB_DATABASE"] ?? ""
        let user = env["DB_USERNAME"] ?? ""
        let password = env["DB_PASSWORD"]

        let siteName = URL(fileURLWithPath: path).lastPathComponent
        let profile = ConnectionProfile(
            name: database.isEmpty ? siteName : database,
            kind: kind,
            host: host,
            port: port,
            user: user,
            database: database
        )
        return ConnectionDraft(profile: profile, password: password?.isEmpty == true ? nil : password)
    }

    static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = unquote(line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces))
        }
        return result
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    private static func kind(for connection: String?) -> DatabaseKind {
        switch connection?.lowercased() {
        case "pgsql", "postgres", "postgresql": .postgres
        case "mongodb": .mongodb
        default: .mysql
        }
    }
}
