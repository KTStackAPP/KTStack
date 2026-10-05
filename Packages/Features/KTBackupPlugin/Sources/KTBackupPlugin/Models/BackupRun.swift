import Foundation

public enum BackupRunStatus: String, Codable, Sendable {
    case running, succeeded, partial, failed, skipped
}

public enum BackupTrigger: String, Codable, Sendable {
    case scheduled, catchUp, manual
}

public enum BackupSkipReason: String, Codable, Sendable {
    case onBattery, engineStopped, nothingSelected

    public var message: String {
        switch self {
        case .onBattery: "Skipped on battery power; will retry on AC power."
        case .engineStopped: "Skipped because the database engines for this plan aren't running."
        case .nothingSelected: "Skipped because nothing is selected in this plan."
        }
    }
}

public struct BackupRunItem: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case database, site, settings
    }

    public var kind: Kind
    public var name: String
    public var succeeded: Bool
    public var message: String?

    public init(kind: Kind, name: String, succeeded: Bool, message: String? = nil) {
        self.kind = kind
        self.name = name
        self.succeeded = succeeded
        self.message = message
    }
}

public struct BackupRun: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var planID: UUID
    public var trigger: BackupTrigger
    public var startedAt: Date
    public var finishedAt: Date?
    public var status: BackupRunStatus
    public var skipReason: BackupSkipReason?
    public var items: [BackupRunItem]
    public var archiveName: String?
    public var sizeBytes: Int64?
    public var sha256: String?
    public var remoteID: String?
    public var message: String?
    public var warnings: [String]

    public init(id: UUID = UUID(), planID: UUID, trigger: BackupTrigger, startedAt: Date, finishedAt: Date? = nil,
                status: BackupRunStatus = .running, skipReason: BackupSkipReason? = nil, items: [BackupRunItem] = [],
                archiveName: String? = nil, sizeBytes: Int64? = nil, sha256: String? = nil, remoteID: String? = nil,
                message: String? = nil, warnings: [String] = []) {
        self.id = id
        self.planID = planID
        self.trigger = trigger
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.skipReason = skipReason
        self.items = items
        self.archiveName = archiveName
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.remoteID = remoteID
        self.message = message
        self.warnings = warnings
    }

    public var countsAsAttempt: Bool {
        !(status == .skipped && skipReason == .onBattery)
    }

    public static func status(for items: [BackupRunItem]) -> BackupRunStatus {
        let succeeded = items.filter(\.succeeded).count
        if succeeded == items.count, !items.isEmpty { return .succeeded }
        return succeeded == 0 ? .failed : .partial
    }
}
