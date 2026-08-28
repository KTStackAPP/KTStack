import Foundation

public struct QueryFavorite: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var sql: String
    public let savedAt: Date

    public init(id: UUID = UUID(), name: String, sql: String, savedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.sql = sql
        self.savedAt = savedAt
    }
}
