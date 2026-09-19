import Foundation

/// Danh tính một tab workspace: bảng hoặc query, gắn với (profile, database) cụ thể.
public enum WorkspaceTab: Identifiable, Equatable {
    case table(profileID: UUID, database: String, table: TableInfo)
    case query(profileID: UUID, database: String, id: UUID)

    public var id: String {
        switch self {
        case let .table(profileID, database, table):
            "tbl:\(profileID.uuidString):\(database):\(table.name)"
        case let .query(profileID, database, id):
            "qry:\(profileID.uuidString):\(database):\(id.uuidString)"
        }
    }

    public var profileID: UUID {
        switch self {
        case let .table(profileID, _, _), let .query(profileID, _, _): profileID
        }
    }

    public var database: String {
        switch self {
        case let .table(_, database, _), let .query(_, database, _): database
        }
    }

    public var title: String {
        switch self {
        case let .table(_, _, table): table.name
        case .query: "Query"
        }
    }

    public var isQuery: Bool {
        if case .query = self { return true }
        return false
    }
}
