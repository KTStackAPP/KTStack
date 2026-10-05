import Foundation

public struct BackupDatabaseSelection: Codable, Hashable, Sendable {
    public var engine: String
    public var database: String

    public init(engine: String, database: String) {
        self.engine = engine
        self.database = database
    }
}

public struct BackupPlan: Codable, Equatable, Identifiable, Sendable {
    public static let defaultKeepLast = 7

    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var enabledAt: Date?
    public var schedule: BackupSchedule
    public var keepLast: Int
    public var databases: [BackupDatabaseSelection]
    public var includeSites: Bool
    public var siteIDs: [UUID]
    public var siteExcludes: [String]
    public var includeSettings: Bool
    public var destinationID: UUID?
    public var keepLocalCopy: Bool
    public var skipOnBattery: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = false,
        enabledAt: Date? = nil,
        schedule: BackupSchedule = .nightly,
        keepLast: Int = BackupPlan.defaultKeepLast,
        databases: [BackupDatabaseSelection] = [],
        includeSites: Bool = false,
        siteIDs: [UUID] = [],
        siteExcludes: [String] = SiteExcludeDefaults.patterns,
        includeSettings: Bool = false,
        destinationID: UUID? = nil,
        keepLocalCopy: Bool = false,
        skipOnBattery: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.enabledAt = enabledAt
        self.schedule = schedule
        self.keepLast = max(1, keepLast)
        self.databases = databases
        self.includeSites = includeSites
        self.siteIDs = siteIDs
        self.siteExcludes = siteExcludes
        self.includeSettings = includeSettings
        self.destinationID = destinationID
        self.keepLocalCopy = keepLocalCopy
        self.skipOnBattery = skipOnBattery
    }

    public var hasContent: Bool {
        !databases.isEmpty || (includeSites && !siteIDs.isEmpty) || includeSettings
    }

    public var shortID: String {
        String(id.uuidString.prefix(8)).lowercased()
    }

    public mutating func setEnabled(_ enabled: Bool, at date: Date) {
        if enabled && !isEnabled {
            enabledAt = date
        }
        isEnabled = enabled
    }
}

public enum SiteExcludeDefaults {
    public static let patterns = [
        "node_modules", "vendor", ".git", "storage/logs", "*.log",
        ".DS_Store", ".next", "dist", "build", ".cache"
    ]
}
