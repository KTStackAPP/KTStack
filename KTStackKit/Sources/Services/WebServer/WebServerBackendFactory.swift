import Foundation

public enum WebServerBackendFactory {
    public static func backend(for engine: WebServerEngine) -> WebServerBackend {
        switch engine {
        case .nginx:
            NginxBackend()
        case .apache:
            preconditionFailure("Apache backend is not wired until its phase")
        }
    }
}
