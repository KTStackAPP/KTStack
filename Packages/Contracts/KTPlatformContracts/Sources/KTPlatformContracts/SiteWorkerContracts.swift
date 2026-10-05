import Foundation
import KTStackCore

public enum SiteWorkerRunState: String, Sendable, Equatable, CaseIterable {
    case stopped
    case waitingForServer
    case starting
    case running
    case backoff
    case crashed
    case failed

    public var label: String {
        switch self {
        case .stopped: "Stopped"
        case .waitingForServer: "Starts with the server"
        case .starting: "Starting"
        case .running: "Running"
        case .backoff: "Restarting"
        case .crashed: "Crashed"
        case .failed: "Failed to start"
        }
    }

    public var isActive: Bool {
        switch self {
        case .starting, .running, .backoff: true
        case .stopped, .waitingForServer, .crashed, .failed: false
        }
    }
}

public struct SiteWorkerStatus: Sendable, Equatable, Hashable {
    public var state: SiteWorkerRunState
    public var restarts: Int
    public var lastExitStatus: Int32?
    public var nextAttemptAt: Date?
    public var message: String?

    public init(
        state: SiteWorkerRunState,
        restarts: Int = 0,
        lastExitStatus: Int32? = nil,
        nextAttemptAt: Date? = nil,
        message: String? = nil
    ) {
        self.state = state
        self.restarts = restarts
        self.lastExitStatus = lastExitStatus
        self.nextAttemptAt = nextAttemptAt
        self.message = message
    }

    public var needsAttention: Bool {
        state == .crashed || state == .failed
    }

    public static let stopped = SiteWorkerStatus(state: .stopped)
}

public struct SiteWorkersState: Sendable, Equatable {
    public var statuses: [UUID: SiteWorkerStatus]

    public init(statuses: [UUID: SiteWorkerStatus] = [:]) {
        self.statuses = statuses
    }

    public func status(of workerID: UUID) -> SiteWorkerStatus {
        statuses[workerID] ?? .stopped
    }
}

public protocol SiteWorkerManaging: AnyObject {
    @MainActor var workersState: SiteWorkersState { get }
    @MainActor func workersStateStream() -> AsyncStream<SiteWorkersState>
    @MainActor func setWorkers(_ siteID: UUID, _ workers: [SiteWorker]) throws
    @MainActor func startWorker(siteID: UUID, workerID: UUID)
    @MainActor func stopWorker(siteID: UUID, workerID: UUID)
    @MainActor func restartWorker(siteID: UUID, workerID: UUID)
    @MainActor func workerLogSourceID(siteID: UUID, workerID: UUID) -> String?
}
