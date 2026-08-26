import Foundation
import KTStackCore

public enum ServiceStatus: String, CaseIterable, Sendable {
    case running, stopped, starting, stopping, warning, error, info

    public var symbolName: String {
        switch self {
        case .running: "circle.fill"
        case .stopped: "circle"
        case .starting: "circle.dotted"
        case .stopping: "circle.dotted"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle"
        }
    }

    public var label: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .warning: "Warning"
        case .error: "Error"
        case .info: "Info"
        }
    }
}

public enum SiteType: String, Codable, CaseIterable, Sendable {
    case php
    case staticSite
    case node
    case proxy

    public var label: String {
        switch self {
        case .php: "PHP"
        case .staticSite: "Static"
        case .node: "Node"
        case .proxy: "Proxy"
        }
    }

    public var symbolName: String {
        switch self {
        case .php: "chevron.left.forwardslash.chevron.right"
        case .staticSite: "doc.richtext"
        case .node: "shippingbox"
        case .proxy: "arrow.left.arrow.right"
        }
    }
}

public struct Site: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String
    public var docroot: String
    public var domain: String
    public var phpVersion: String
    public var type: SiteType
    public var databaseName: String?
    public var secure: Bool
    public var nodePort: Int?
    public var nodeCommand: String?
    public var nodeEnabled: Bool
    public var serverEngine: WebServerEngine
    // Loopback port the front terminator routes this site's PHP backend to. Only PHP sites
    // have one; static/node are served by the front directly. Assigned by SiteRegistry.
    public var backendPort: Int?
    // Upstream URL for a proxy site (e.g. "http://127.0.0.1:8000"); nil for every other type.
    public var proxyTarget: String?
    // Extra .tld domains served alongside `domain`; they join server_name and the cert SANs.
    public var aliases: [String]
    // Per-site env vars for the PHP backend (fastcgi_param/SetEnv) and Node start (export).
    public var envVars: [String: String]
    // Verbatim nginx directives spliced into this site's front server block; scope in the name so a backend variant can follow.
    public var frontDirectives: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        docroot: String,
        domain: String,
        phpVersion: String,
        type: SiteType,
        databaseName: String? = nil,
        secure: Bool = false,
        nodePort: Int? = nil,
        nodeCommand: String? = nil,
        nodeEnabled: Bool = false,
        serverEngine: WebServerEngine = .nginx,
        backendPort: Int? = nil,
        proxyTarget: String? = nil,
        aliases: [String] = [],
        envVars: [String: String] = [:],
        frontDirectives: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.docroot = docroot
        self.domain = domain
        self.phpVersion = phpVersion
        self.type = type
        self.databaseName = databaseName
        self.secure = secure
        self.nodePort = nodePort
        self.nodeCommand = nodeCommand
        self.nodeEnabled = nodeEnabled
        self.serverEngine = serverEngine
        self.backendPort = backendPort
        self.proxyTarget = proxyTarget
        self.aliases = aliases
        self.envVars = envVars
        self.frontDirectives = frontDirectives
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, docroot, domain, phpVersion, type, databaseName, secure
        case nodePort, nodeCommand, nodeEnabled, serverEngine, backendPort, proxyTarget
        case aliases, envVars, frontDirectives
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        docroot = try c.decode(String.self, forKey: .docroot)
        domain = try c.decode(String.self, forKey: .domain)
        phpVersion = try c.decode(String.self, forKey: .phpVersion)
        type = try c.decode(SiteType.self, forKey: .type)
        databaseName = try c.decodeIfPresent(String.self, forKey: .databaseName)
        secure = try c.decodeIfPresent(Bool.self, forKey: .secure) ?? false
        nodePort = try c.decodeIfPresent(Int.self, forKey: .nodePort)
        nodeCommand = try c.decodeIfPresent(String.self, forKey: .nodeCommand)
        nodeEnabled = try c.decodeIfPresent(Bool.self, forKey: .nodeEnabled) ?? false
        // Old sites.json has no serverEngine; default to nginx so existing installs are untouched.
        serverEngine = try c.decodeIfPresent(WebServerEngine.self, forKey: .serverEngine) ?? .nginx
        // nil for old installs; SiteRegistry backfills a port for PHP sites before the front renders.
        backendPort = try c.decodeIfPresent(Int.self, forKey: .backendPort)
        proxyTarget = try c.decodeIfPresent(String.self, forKey: .proxyTarget)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        envVars = try c.decodeIfPresent([String: String].self, forKey: .envVars) ?? [:]
        frontDirectives = try c.decodeIfPresent(String.self, forKey: .frontDirectives)
    }

    // Có thư mục trên đĩa; proxy site không có nên mọi thao tác folder phải gate cái này.
    public var hasFolder: Bool { !path.isEmpty }

    // domain chính + alias, dùng cho server_name và cert SAN.
    public var serverNames: [String] { [domain] + aliases }

    // Có directives không rỗng sau trim; generator chỉ ghi file + include khi true.
    public var hasFrontDirectives: Bool {
        (frontDirectives?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    // Parse target đã lưu; chỉ hợp lệ khi là proxy site.
    public var proxyUpstream: ProxyTarget? {
        guard type == .proxy, let proxyTarget,
              case let .success(target) = ProxyTarget.parse(proxyTarget)
        else { return nil }
        return target
    }

    public static let sample: [Site] = []
}
