import Foundation

public struct WorkerStatus: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case running
        case backoff
        case crashed
        case stopped
        case failedToStart
    }

    public var state: State
    public var pid: Int32?
    public var restarts: Int
    public var lastExitStatus: Int32?
    public var nextAttemptAt: Date?
    public var message: String?
    public var updatedAt: Date

    public init(
        state: State,
        pid: Int32? = nil,
        restarts: Int = 0,
        lastExitStatus: Int32? = nil,
        nextAttemptAt: Date? = nil,
        message: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.state = state
        self.pid = pid
        self.restarts = restarts
        self.lastExitStatus = lastExitStatus
        self.nextAttemptAt = nextAttemptAt
        self.message = message
        self.updatedAt = updatedAt
    }

    public static func read(from url: URL) -> WorkerStatus? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WorkerStatus.self, from: data)
    }

    public func write(to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? data.write(to: url, options: .atomic)
    }
}
