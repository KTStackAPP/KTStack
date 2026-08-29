import Foundation

/// Khóa cache schema theo (profile, database); một kết nối có nhiều database.
public struct SchemaKey: Hashable, Sendable {
    public let profileID: UUID
    public let database: String

    public init(profileID: UUID, database: String) {
        self.profileID = profileID
        self.database = database
    }
}

/// Ảnh chụp object của một database: tables + views trộn chung (phân loại qua isView).
public struct SchemaSnapshot: Equatable, Sendable {
    public var objects: [TableInfo]
    public var loadedAt: Date

    public init(objects: [TableInfo], loadedAt: Date = Date()) {
        self.objects = objects
        self.loadedAt = loadedAt
    }

    public var tables: [TableInfo] {
        objects.filter { !$0.isView }
    }

    public var views: [TableInfo] {
        objects.filter(\.isView)
    }
}
