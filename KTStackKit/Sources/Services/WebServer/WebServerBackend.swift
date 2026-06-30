import Foundation

public enum WebServerEngine: String, Codable, Sendable, CaseIterable {
    case nginx
    case apache
}

public struct BackendRenderContext: Sendable {
    public let site: Site
    public let root: URL
    public let phpFpmSocket: URL?
    public let nodeProxyPort: Int?
    public let certFile: URL?
    public let keyFile: URL?
    public let accessLog: URL
    public let errorLog: URL
    public let port: Int

    public init(
        site: Site,
        root: URL,
        phpFpmSocket: URL?,
        nodeProxyPort: Int?,
        certFile: URL?,
        keyFile: URL?,
        accessLog: URL,
        errorLog: URL,
        port: Int
    ) {
        self.site = site
        self.root = root
        self.phpFpmSocket = phpFpmSocket
        self.nodeProxyPort = nodeProxyPort
        self.certFile = certFile
        self.keyFile = keyFile
        self.accessLog = accessLog
        self.errorLog = errorLog
        self.port = port
    }

    public var terminatesTLS: Bool {
        certFile != nil && keyFile != nil
    }
}

public protocol WebServerBackend: Sendable {
    var engine: WebServerEngine { get }
    func siteConfig(context: BackendRenderContext) -> String
}
