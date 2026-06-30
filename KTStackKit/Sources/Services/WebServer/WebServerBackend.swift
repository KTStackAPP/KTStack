import Foundation

// List every engine up front so serverEngine never needs a migration later. Only nginx
// is wired today. Raw values are persisted, don't rename them.
public enum WebServerEngine: String, Codable, Sendable, CaseIterable {
    case nginx
    case apache
}

// Everything a backend needs to render one PHP site's loopback config. The front terminates
// TLS and proxies here over plain HTTP, so `secure` only drives the pinned SERVER_PORT/HTTPS
// FastCGI params, not a TLS listener on the backend.
public struct BackendRenderContext: Sendable {
    public let domain: String
    public let root: URL
    public let phpFpmSocket: URL
    public let backendPort: Int
    public let secure: Bool
    public let pidFile: URL
    public let accessLog: URL
    public let errorLog: URL

    public init(
        domain: String,
        root: URL,
        phpFpmSocket: URL,
        backendPort: Int,
        secure: Bool,
        pidFile: URL,
        accessLog: URL,
        errorLog: URL
    ) {
        self.domain = domain
        self.root = root
        self.phpFpmSocket = phpFpmSocket
        self.backendPort = backendPort
        self.secure = secure
        self.pidFile = pidFile
        self.accessLog = accessLog
        self.errorLog = errorLog
    }
}

// One backend per engine. It renders the standalone server config for a PHP site's loopback
// backend; the front terminator (always nginx) routes to it. Process lifecycle for nginx
// backends runs through NginxController; Apache adds its own in its phase.
public protocol WebServerBackend: Sendable {
    var engine: WebServerEngine { get }
    func backendConfig(context: BackendRenderContext) -> String
}
