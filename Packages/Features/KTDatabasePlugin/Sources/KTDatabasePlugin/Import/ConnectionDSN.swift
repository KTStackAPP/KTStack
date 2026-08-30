import Foundation

enum ConnectionDSNError: Error, LocalizedError, Equatable {
    case unsupportedScheme(String)
    case missingHost
    case malformed

    var errorDescription: String? {
        switch self {
        case let .unsupportedScheme(scheme):
            "Unsupported scheme \"\(scheme)\". Use mysql://, postgres://, postgresql:// or mongodb://."
        case .missingHost:
            "The URL has no host."
        case .malformed:
            "Could not read that URL. Expected mysql://user:password@host:3306/database."
        }
    }
}

/// Đọc DSN kiểu mysql://user:pass@host:3306/db thành draft kết nối. Query string bị bỏ qua.
enum ConnectionDSN {
    static func parse(_ text: String) throws -> ConnectionDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let components = URLComponents(string: trimmed) else {
            throw ConnectionDSNError.malformed
        }
        guard let scheme = components.scheme?.lowercased(), !scheme.isEmpty else {
            throw ConnectionDSNError.malformed
        }
        guard let kind = kind(for: scheme) else {
            throw ConnectionDSNError.unsupportedScheme(scheme)
        }
        guard let host = components.host, !host.isEmpty else {
            throw ConnectionDSNError.missingHost
        }

        let user = components.user ?? ""
        let password = components.password
        let database = String(components.path.drop { $0 == "/" })
        let port = components.port ?? kind.defaultPort

        let profile = ConnectionProfile(
            name: database.isEmpty ? (user.isEmpty ? host : "\(user)@\(host)") : database,
            kind: kind,
            host: host,
            port: port,
            user: user,
            database: database
        )
        return ConnectionDraft(profile: profile, password: password?.isEmpty == true ? nil : password)
    }

    private static func kind(for scheme: String) -> DatabaseKind? {
        switch scheme {
        case "mysql": .mysql
        case "postgres", "postgresql": .postgres
        case "mongodb": .mongodb
        default: nil
        }
    }
}
