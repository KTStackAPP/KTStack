import Foundation

public struct SiteWorker: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var command: String
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, command: String, enabled: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, command, enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        command = try c.decode(String.self, forKey: .command)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
}

public enum SiteWorkerPreset: String, CaseIterable, Sendable {
    case laravelQueue
    case laravelScheduler

    public var name: String {
        switch self {
        case .laravelQueue: "queue"
        case .laravelScheduler: "scheduler"
        }
    }

    public var title: String {
        switch self {
        case .laravelQueue: "Queue worker"
        case .laravelScheduler: "Scheduler"
        }
    }

    public var command: String {
        switch self {
        case .laravelQueue: "php artisan queue:work --tries=3"
        case .laravelScheduler: "php artisan schedule:work"
        }
    }

    public func makeWorker() -> SiteWorker {
        SiteWorker(name: name, command: command)
    }
}
