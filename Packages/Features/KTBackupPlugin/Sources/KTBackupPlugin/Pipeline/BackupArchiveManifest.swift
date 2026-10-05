import Foundation

public struct BackupArchiveManifest: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public static let fileName = "manifest.json"

    public struct DatabaseEntry: Codable, Equatable, Sendable {
        public var engine: String
        public var database: String
        public var path: String
    }

    public struct SiteEntry: Codable, Equatable, Sendable {
        public var siteID: UUID
        public var name: String
        public var path: String
    }

    public var formatVersion: Int
    public var planID: UUID
    public var planName: String
    public var createdAt: Date
    public var databases: [DatabaseEntry]
    public var sites: [SiteEntry]
    public var settingsPath: String?

    public init(planID: UUID, planName: String, createdAt: Date, databases: [DatabaseEntry] = [],
                sites: [SiteEntry] = [], settingsPath: String? = nil) {
        formatVersion = Self.currentFormatVersion
        self.planID = planID
        self.planName = planName
        self.createdAt = createdAt
        self.databases = databases
        self.sites = sites
        self.settingsPath = settingsPath
    }

    func write(in directory: URL) throws {
        let data = try JSONFileStore<Self>.encoder.encode(self)
        try data.write(to: directory.appendingPathComponent(Self.fileName), options: .atomic)
    }

    static func read(in directory: URL) throws -> BackupArchiveManifest {
        let data = try Data(contentsOf: directory.appendingPathComponent(fileName))
        return try JSONFileStore<Self>.decoder.decode(Self.self, from: data)
    }
}
