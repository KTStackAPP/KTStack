import Foundation

public struct ServiceEngineRetiredData: Sendable, Equatable, Identifiable {
    public let engine: ServiceEngine
    public let version: String
    public let path: String
    public let removedAt: Date
    public let sizeBytes: Int64

    public init(engine: ServiceEngine, version: String, path: String, removedAt: Date, sizeBytes: Int64) {
        self.engine = engine
        self.version = version
        self.path = path
        self.removedAt = removedAt
        self.sizeBytes = sizeBytes
    }

    public var id: String { path }
}

public struct ServiceEngineDataFootprint: Sendable, Equatable {
    public let path: String
    public let sizeBytes: Int64

    public init(path: String, sizeBytes: Int64) {
        self.path = path
        self.sizeBytes = sizeBytes
    }
}
