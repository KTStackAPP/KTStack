import Foundation

/// A stable way to point at one existing row for UPDATE/DELETE. Built from the primary key,
/// falling back to a non-null unique key when the table has no primary key.
public struct RowIdentity: Sendable, Hashable {
    public enum Source: Sendable, Hashable {
        case primaryKey
        case uniqueKey(String)
    }

    public let key: [ColumnValue]
    public let source: Source

    public init(key: [ColumnValue], source: Source) {
        self.key = key
        self.source = source
    }

    // Thứ tự ổn định cho commit/preview độc lập với thứ tự người dùng thao tác.
    public var signature: String {
        let cols = key.map { "\($0.column)=\(RowIdentity.token($0.value))" }.joined(separator: "&")
        switch source {
        case .primaryKey: return "pk|\(cols)"
        case let .uniqueKey(name): return "uk:\(name)|\(cols)"
        }
    }

    private static func token(_ cell: Cell) -> String {
        switch cell {
        case let .text(text): "t:\(text)"
        case let .int(number): "i:\(number)"
        case let .double(number): "d:\(number)"
        case let .bool(flag): "b:\(flag ? 1 : 0)"
        case .null: "∅"
        case let .blob(data): "x:\(data.count)"
        }
    }
}

/// Resolves a row's identity from table metadata: primary key first, then the first non-null
/// unique key whose columns are all present. Returns nil for a keyless row, which stays read-only.
public struct RowIdentityResolver: Sendable {
    public let columns: [ColumnInfo]
    public let uniqueIndexes: [IndexInfo]

    public init(columns: [ColumnInfo], uniqueIndexes: [IndexInfo] = []) {
        self.columns = columns
        self.uniqueIndexes = uniqueIndexes
    }

    public func identity(for row: [String: Cell]) -> RowIdentity? {
        let pkNames = columns.primaryKeyColumns.map(\.name)
        if let key = usableKey(names: pkNames, row: row) {
            return RowIdentity(key: key, source: .primaryKey)
        }
        for index in uniqueIndexes where index.isUnique {
            if let key = usableKey(names: index.columns, row: row) {
                return RowIdentity(key: key, source: .uniqueKey(index.name))
            }
        }
        return nil
    }

    // Hợp lệ khi có đủ cột, không cột nào thiếu và không cột nào NULL (NULL không định danh 1 hàng).
    private func usableKey(names: [String], row: [String: Cell]) -> [ColumnValue]? {
        guard !names.isEmpty else { return nil }
        var key: [ColumnValue] = []
        for name in names {
            guard let value = row[name], value != .null else { return nil }
            key.append(ColumnValue(column: name, value: value))
        }
        return key
    }
}
