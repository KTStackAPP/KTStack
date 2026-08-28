import Foundation

/// The editor a column's SQL type calls for. Derived from `ColumnInfo.dataType` so the grid can pick
/// a bool toggle, date picker, enum/set list, JSON/binary editor or a plain text field.
public enum CellEditorKind: Equatable, Sendable {
    case text
    case number
    case bool
    case date
    case datetime
    case time
    case enumeration([String])
    case setMembership([String])
    case json
    case binary

    public static func forColumn(_ column: ColumnInfo) -> CellEditorKind {
        let raw = column.dataType.trimmingCharacters(in: .whitespaces)
        let type = raw.lowercased()
        if type.hasPrefix("tinyint(1)") || type == "bool" || type == "boolean" { return .bool }
        if type.hasPrefix("enum(") { return .enumeration(parseMembers(raw)) }
        if type.hasPrefix("set(") { return .setMembership(parseMembers(raw)) }
        if type.contains("json") { return .json }
        if type.contains("blob") || type.contains("binary") { return .binary }
        if type.contains("datetime") || type.contains("timestamp") { return .datetime }
        if type == "date" || type.hasPrefix("date ") { return .date }
        if type.contains("time") { return .time }
        if type.contains("int") { return .number }
        if type.contains("decimal") || type.contains("numeric")
            || type.contains("float") || type.contains("double") || type.contains("real") {
            return .number
        }
        return .text
    }

    // Tách thành viên trong enum('a','b') / set('a','b'): bỏ dấu nháy, '' là nháy escape.
    private static func parseMembers(_ type: String) -> [String] {
        guard let open = type.firstIndex(of: "("),
              let close = type.lastIndex(of: ")"), open < close else { return [] }
        let inner = Array(type[type.index(after: open)..<close])
        var members: [String] = []
        var current = ""
        var insideQuotes = false
        var index = 0
        while index < inner.count {
            let character = inner[index]
            if insideQuotes {
                if character == "'" {
                    if index + 1 < inner.count, inner[index + 1] == "'" {
                        current.append("'"); index += 1
                    } else {
                        insideQuotes = false; members.append(current); current = ""
                    }
                } else {
                    current.append(character)
                }
            } else if character == "'" {
                insideQuotes = true
            }
            index += 1
        }
        return members
    }
}

public enum CellEdit: Equatable, Sendable {
    case value(String)
    case null
    case empty
    case now
    case `default`
}

public enum CellCoercionError: Error, Equatable {
    case notNullable
    case notInEnum(String)
    case invalidSetMembers([String])
    case defaultNotCoercible
}

/// Turns a typed edit into a bound `Cell`, honouring nullability and the column's editor kind. An
/// empty entered value on a nullable column becomes NULL, matching inline-edit expectations.
public enum CellCoercion {
    public static func cell(
        for edit: CellEdit,
        column: ColumnInfo,
        kind: CellEditorKind,
        now: Date = Date()
    ) throws -> Cell {
        switch edit {
        case .null:
            guard column.isNullable else { throw CellCoercionError.notNullable }
            return .null
        case .empty:
            return .text("")
        case .now:
            return .text(timestampString(kind: kind, date: now))
        case .default:
            // DEFAULT là keyword, không phải Cell; phải đi qua đường unbound của editor.
            throw CellCoercionError.defaultNotCoercible
        case let .value(raw):
            return try coerceValue(raw, column: column, kind: kind)
        }
    }

    public static func timestampString(
        kind: CellEditorKind,
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        switch kind {
        case .date: formatter.dateFormat = "yyyy-MM-dd"
        case .time: formatter.dateFormat = "HH:mm:ss"
        default: formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.string(from: date)
    }

    private static func coerceValue(_ raw: String, column: ColumnInfo, kind: CellEditorKind) throws -> Cell {
        if raw.isEmpty {
            return column.isNullable ? .null : .text("")
        }
        switch kind {
        case .bool:
            if let flag = boolValue(raw) { return .bool(flag) }
            return .text(raw)
        case .number:
            if let integer = Int64(raw) { return .int(integer) }
            if let double = Double(raw) { return .double(double) }
            return .text(raw)
        case let .enumeration(members):
            guard members.contains(raw) else { throw CellCoercionError.notInEnum(raw) }
            return .text(raw)
        case let .setMembership(members):
            let picked = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let invalid = picked.filter { !members.contains($0) }
            guard invalid.isEmpty else { throw CellCoercionError.invalidSetMembers(invalid) }
            return .text(picked.joined(separator: ","))
        case .text, .date, .datetime, .time, .json, .binary:
            return .text(raw)
        }
    }

    private static func boolValue(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "1", "true", "yes", "t", "y": true
        case "0", "false", "no", "f", "n": false
        default: nil
        }
    }
}
