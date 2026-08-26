import Foundation

// Upstream cho proxy site: scheme + host + port, không path/query/userinfo.
public struct ProxyTarget: Hashable, Sendable {
    public enum Scheme: String, Sendable {
        case http, https
        var defaultPort: Int { self == .https ? 443 : 80 }
    }

    public let scheme: Scheme
    public let host: String
    public let port: Int

    public init(scheme: Scheme, host: String, port: Int) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    public static func loopback(port: Int) -> ProxyTarget {
        ProxyTarget(scheme: .http, host: "127.0.0.1", port: port)
    }

    // "http://127.0.0.1:8000" — port luôn hiện, dùng cho proxy_pass.
    public var upstreamURLString: String {
        "\(scheme.rawValue)://\(host):\(port)"
    }

    // Bỏ port mặc định cho UI: "https://api.example.com", "http://127.0.0.1:8000".
    public var displayString: String {
        port == scheme.defaultPort ? "\(scheme.rawValue)://\(host)" : upstreamURLString
    }

    public static func parse(_ raw: String) -> Result<ProxyTarget, ProxyTargetError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }

        var scheme: Scheme = .http
        var authority = trimmed
        if let range = trimmed.range(of: "://") {
            let rawScheme = String(trimmed[trimmed.startIndex..<range.lowerBound]).lowercased()
            guard let parsed = Scheme(rawValue: rawScheme) else { return .failure(.badScheme) }
            scheme = parsed
            authority = String(trimmed[range.upperBound...])
        }

        guard !authority.isEmpty else { return .failure(.badHost) }
        // Chặn path/query/fragment/userinfo và ký tự chèn.
        if authority.contains("/") { return .failure(.pathNotAllowed) }
        if authority.rangeOfCharacter(from: CharacterSet(charactersIn: "?#@ \t;{}")) != nil {
            return .failure(.badHost)
        }

        let host: String
        let port: Int
        if let colon = authority.lastIndex(of: ":") {
            host = String(authority[authority.startIndex..<colon])
            let portText = String(authority[authority.index(after: colon)...])
            guard let value = Int(portText), (1...65535).contains(value) else {
                return .failure(.badPort)
            }
            port = value
        } else {
            host = authority
            port = scheme.defaultPort
        }

        guard HostSyntax.isValidHost(host) else { return .failure(.badHost) }
        return .success(ProxyTarget(scheme: scheme, host: host, port: port))
    }
}

public enum ProxyTargetError: LocalizedError, Equatable {
    case emptyInput
    case badScheme
    case badHost
    case badPort
    case pathNotAllowed

    public var errorDescription: String? {
        switch self {
        case .emptyInput: "Enter a target URL."
        case .badScheme: "Target must start with http:// or https://."
        case .badHost: "Target host is not valid."
        case .badPort: "Target port must be between 1 and 65535."
        case .pathNotAllowed: "Target cannot include a path, query, or credentials."
        }
    }
}
