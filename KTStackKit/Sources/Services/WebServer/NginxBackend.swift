import Foundation

public struct NginxBackend: WebServerBackend {
    public let engine: WebServerEngine = .nginx

    private let writer = NginxBackendConfigWriter()

    public init() {}

    public func backendConfig(context: BackendRenderContext) -> String {
        writer.config(
            domain: context.domain,
            root: context.root,
            phpFpmSocket: context.phpFpmSocket,
            backendPort: context.backendPort,
            secure: context.secure,
            pid: context.pidFile,
            accessLog: context.accessLog,
            errorLog: context.errorLog
        )
    }
}
