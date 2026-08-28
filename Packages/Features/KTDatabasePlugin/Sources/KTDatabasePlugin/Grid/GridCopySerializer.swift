import Foundation

public enum GridCopyFormat: Sendable, Equatable {
    case tsv
    case csv
    case json
    case markdown
    case sqlInsert(table: String)
    case sqlUpdate(table: String, keyColumns: [String])
    case inList
}

/// Turns a rectangular slice of a `QueryResult` into clipboard text. Text formats (tsv/csv/markdown)
/// flatten NULL to an empty cell (spreadsheet convention); structured formats (json/sql) keep NULL,
/// numbers, booleans and blobs distinct. Values are literalized here because copy is an export the
/// user pastes elsewhere, not the pre-commit `SQLPreview`.
public struct GridCopySerializer: Sendable {
    public let quote: Character

    public init(quote: Character = "`") {
        self.quote = quote
    }

    public func serialize(
        _ result: QueryResult,
        rows: [Int],
        columns: [Int],
        format: GridCopyFormat
    ) -> String {
        let rows = rows.filter { result.rows.indices.contains($0) }
        let columns = columns.filter { result.columns.indices.contains($0) }
        switch format {
        case .tsv: return delimited(result, rows: rows, columns: columns, delimiter: "\t", lineEnding: "\n")
        case .csv: return delimited(result, rows: rows, columns: columns, delimiter: ",", lineEnding: "\r\n")
        case .json: return json(result, rows: rows, columns: columns)
        case .markdown: return markdown(result, rows: rows, columns: columns)
        case let .sqlInsert(table): return sqlInsert(result, rows: rows, columns: columns, table: table)
        case let .sqlUpdate(table, keys): return sqlUpdate(result, rows: rows, columns: columns, table: table, keyColumns: keys)
        case .inList: return inList(result, rows: rows, columns: columns)
        }
    }

    private func header(_ result: QueryResult, columns: [Int]) -> [String] {
        columns.map { result.columns[$0].name }
    }

    private func delimited(_ result: QueryResult, rows: [Int], columns: [Int], delimiter: String, lineEnding: String) -> String {
        var lines: [String] = []
        for row in rows {
            let fields = columns.map { escapeDelimited(result.rows[row][$0].displayText ?? "", delimiter: delimiter) }
            lines.append(fields.joined(separator: delimiter))
        }
        return lines.joined(separator: lineEnding)
    }

    private func escapeDelimited(_ field: String, delimiter: String) -> String {
        let mustQuote = field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard mustQuote else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func json(_ result: QueryResult, rows: [Int], columns: [Int]) -> String {
        let names = header(result, columns: columns)
        let objects: [[String: Any]] = rows.map { row in
            var object: [String: Any] = [:]
            for (offset, column) in columns.enumerated() {
                object[names[offset]] = jsonValue(result.rows[row][column])
            }
            return object
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: objects,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "[]" }
        return String(bytes: data, encoding: .utf8) ?? "[]"
    }

    private func jsonValue(_ cell: Cell) -> Any {
        switch cell {
        case .null: NSNull()
        case let .text(text): text
        case let .int(number): number
        case let .double(number): number
        case let .bool(flag): flag
        case let .blob(data): data.base64EncodedString()
        }
    }

    private func markdown(_ result: QueryResult, rows: [Int], columns: [Int]) -> String {
        let names = header(result, columns: columns).map(escapeMarkdown)
        var lines = ["| \(names.joined(separator: " | ")) |"]
        lines.append("| \(names.map { _ in "---" }.joined(separator: " | ")) |")
        for row in rows {
            let fields = columns.map { escapeMarkdown(result.rows[row][$0].displayText ?? "") }
            lines.append("| \(fields.joined(separator: " | ")) |")
        }
        return lines.joined(separator: "\n")
    }

    private func escapeMarkdown(_ field: String) -> String {
        field
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func sqlInsert(_ result: QueryResult, rows: [Int], columns: [Int], table: String) -> String {
        guard !columns.isEmpty, !rows.isEmpty else { return "" }
        let columnList = columns.map { quoteIdent(result.columns[$0].name) }.joined(separator: ", ")
        let tuples = rows.map { row in
            "(" + columns.map { sqlLiteral(result.rows[row][$0]) }.joined(separator: ", ") + ")"
        }
        return "INSERT INTO \(quoteIdent(table)) (\(columnList)) VALUES\n" + tuples.joined(separator: ",\n") + ";"
    }

    private func sqlUpdate(_ result: QueryResult, rows: [Int], columns: [Int], table: String, keyColumns: [String]) -> String {
        guard !rows.isEmpty else { return "" }
        let columnNames = columns.map { result.columns[$0].name }
        let keyIndexByName = Dictionary(uniqueKeysWithValues: result.columns.enumerated().map { ($0.element.name, $0.offset) })
        var statements: [String] = []
        for row in rows {
            let assignments = zip(columnNames, columns)
                .filter { !keyColumns.contains($0.0) }
                .map { "\(quoteIdent($0.0)) = \(sqlLiteral(result.rows[row][$0.1]))" }
            let conditions = keyColumns.compactMap { name -> String? in
                guard let index = keyIndexByName[name] else { return nil }
                return "\(quoteIdent(name)) = \(sqlLiteral(result.rows[row][index]))"
            }
            guard !assignments.isEmpty, !conditions.isEmpty else { continue }
            statements.append("UPDATE \(quoteIdent(table)) SET \(assignments.joined(separator: ", ")) WHERE \(conditions.joined(separator: " AND "));")
        }
        return statements.joined(separator: "\n")
    }

    private func inList(_ result: QueryResult, rows: [Int], columns: [Int]) -> String {
        guard let column = columns.first else { return "()" }
        let values = rows.map { sqlLiteral(result.rows[$0][column]) }
        return "(" + values.joined(separator: ", ") + ")"
    }

    private func sqlLiteral(_ cell: Cell) -> String {
        switch cell {
        case .null: "NULL"
        case let .int(number): String(number)
        case let .double(number): String(number)
        case let .bool(flag): flag ? "1" : "0"
        case let .text(text): "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
        case let .blob(data): "x'" + data.map { String(format: "%02x", $0) }.joined() + "'"
        }
    }

    private func quoteIdent(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: String(quote), with: String(repeating: quote, count: 2))
        return "\(quote)\(escaped)\(quote)"
    }
}
