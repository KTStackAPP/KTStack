import Foundation

public enum ServiceKind: String, CaseIterable, Sendable, Hashable {
    case nginx, phpFpm, dnsmasq, mysql, postgres, redis, mongodb, mailpit

    public var displayName: String {
        switch self {
        case .nginx:    return "Nginx"
        case .phpFpm:   return "PHP-FPM"
        case .dnsmasq:  return "dnsmasq"
        case .mysql:    return "MySQL"
        case .postgres: return "PostgreSQL"
        case .redis:    return "Redis"
        case .mongodb:  return "MongoDB"
        case .mailpit:  return "Mailpit"
        }
    }

    public var symbolName: String {
        switch self {
        case .nginx:    return "arrow.triangle.branch"
        case .phpFpm:   return "chevron.left.forwardslash.chevron.right"
        case .dnsmasq:  return "point.3.connected.trianglepath.dotted"
        case .mysql:    return "cylinder.split.1x2"
        case .postgres: return "cylinder.split.1x2.fill"
        case .redis:    return "bolt.fill"
        case .mongodb:  return "leaf.fill"
        case .mailpit:  return "envelope"
        }
    }

    public var defaultPort: Int? {
        switch self {
        case .nginx:    return 443
        case .phpFpm:   return nil
        case .dnsmasq:  return 53
        case .mysql:    return 3306
        case .postgres: return 5432
        case .redis:    return 6379
        case .mongodb:  return 27017
        case .mailpit:  return 8025
        }
    }
    
    public var binaryName: String? {
        switch self {
        case .nginx:    return "nginx"
        case .phpFpm:   return "php-fpm"
        case .dnsmasq:  return "dnsmasq"
        case .mysql:    return "mysqld"
        case .postgres: return "postgres"
        case .redis:    return "redis-server"
        case .mongodb:  return "mongod"
        case .mailpit:  return "mailpit"
        }
    }

    public var launchdLabel: String { "com.ktstack.\(rawValue)" }
}

public protocol ManagedService: AnyObject, Sendable {
    var kind: ServiceKind { get }
   
    var detail: String { get }
    
    var logsURL: URL? { get }

    var isInstalled: Bool { get }

    func start() async throws
    func stop() async throws
    func restart() async throws
   
    func probe() async -> ServiceStatus
}

public struct ServiceSnapshot: Identifiable, Sendable, Hashable {
    public let kind: ServiceKind
    public var status: ServiceStatus
    public var detail: String
    public var isInstalled: Bool
    public var isBusy: Bool
    public var errorMessage: String?
  
    public var installable: Bool

    public var downloadFraction: Double?

    public var cpuPercent: Double?

    public var memoryBytes: Int64?

    public var id: ServiceKind { kind }
    public var displayName: String { kind.displayName }
    public var symbolName: String { kind.symbolName }

    public var metricsText: String? {
        guard status == .running else { return nil }
        var parts: [String] = []
        if let cpuPercent { parts.append(String(format: "CPU %.1f%%", cpuPercent)) }
        if let memoryBytes { parts.append("\(memoryBytes / 1_048_576) MB") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public init(kind: ServiceKind,
                status: ServiceStatus,
                detail: String,
                isInstalled: Bool,
                isBusy: Bool = false,
                errorMessage: String? = nil,
                installable: Bool = false,
                downloadFraction: Double? = nil,
                cpuPercent: Double? = nil,
                memoryBytes: Int64? = nil) {
        self.kind = kind
        self.status = status
        self.detail = detail
        self.isInstalled = isInstalled
        self.isBusy = isBusy
        self.errorMessage = errorMessage
        self.installable = installable
        self.downloadFraction = downloadFraction
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}
