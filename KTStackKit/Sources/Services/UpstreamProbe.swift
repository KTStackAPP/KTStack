import Foundation

// TCP-probe upstream của Node/Proxy site; KTStack không quản lý tiến trình, chỉ hỏi cổng.
public struct UpstreamProbe: Sendable {
    public enum State: String, Equatable, Sendable {
        case running, stopped
    }

    private let health = HealthChecker()

    public init() {}

    public func probe(host: String, port: Int) async -> State {
        await health.check(.tcpHost(host: host, port: port)) == .running ? .running : .stopped
    }
}

public extension UpstreamProbe.State {
    var badgeLabel: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        }
    }

    var isHealthy: Bool {
        self == .running
    }

    var serviceStatus: ServiceStatus {
        switch self {
        case .running: .running
        case .stopped: .stopped
        }
    }
}
