import Foundation

// Nhận diện placeholder :name nằm ngoài chuỗi/backtick/comment (qua SQLSkeleton) và bind giá trị đã đánh kiểu.
// Không nội suy giá trị vào SQL: mỗi :name thành placeholder dialect (? hoặc $n) kèm bind theo thứ tự xuất hiện.
// Bỏ qua := (gán biến MySQL) và :: vì ký tự sau : không phải đầu định danh / trước : là dấu :.
public enum QueryParameterBinder {
    public struct Binding: Equatable {
        public let statement: DMLStatement
        public let missing: [String]

        public init(statement: DMLStatement, missing: [String]) {
            self.statement = statement
            self.missing = missing
        }
    }

    public static func placeholders(in sql: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for name in scan(sql).map(\.name) where seen.insert(name).inserted {
            ordered.append(name)
        }
        return ordered
    }

    public static func hasPlaceholders(_ sql: String) -> Bool {
        !scan(sql).isEmpty
    }

    public static func bind(_ sql: String, values: [String: Cell], dialect: SQLDialect) -> Binding {
        let source = Array(sql)
        let matches = scan(sql)
        guard !matches.isEmpty else {
            return Binding(statement: DMLStatement(sql: sql, binds: []), missing: [])
        }

        var out = ""
        out.reserveCapacity(sql.count)
        var binds: [Cell] = []
        var missing: [String] = []
        var missingSeen = Set<String>()
        var cursor = 0
        var position = 0
        for match in matches {
            if cursor < match.start { out += String(source[cursor..<match.start]) }
            position += 1
            out += dialect.placeholderStyle.placeholder(position)
            if let value = values[match.name] {
                binds.append(value)
            } else {
                binds.append(.null)
                if missingSeen.insert(match.name).inserted { missing.append(match.name) }
            }
            cursor = match.end
        }
        if cursor < source.count { out += String(source[cursor...]) }
        return Binding(statement: DMLStatement(sql: out, binds: binds), missing: missing)
    }

    // Đưa chuỗi người dùng nhập về Cell đã đánh kiểu; NULL không phân biệt hoa thường.
    public static func coerce(_ raw: String) -> Cell {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.uppercased() == "NULL" { return .null }
        if let int = Int64(trimmed) { return .int(int) }
        if let double = Double(trimmed), trimmed.contains(where: { $0 == "." || $0 == "e" || $0 == "E" }) {
            return .double(double)
        }
        return .text(raw)
    }

    private struct Match {
        let name: String
        let start: Int
        let end: Int
    }

    private static func scan(_ sql: String) -> [Match] {
        let source = Array(sql)
        let skeleton = Array(SQLSkeleton.scan(sql).text)
        guard source.count == skeleton.count else { return [] }

        var matches: [Match] = []
        var index = 0
        while index < skeleton.count {
            guard skeleton[index] == ":",
                  index == 0 || skeleton[index - 1] != ":",
                  index + 1 < skeleton.count,
                  isIdentifierStart(skeleton[index + 1])
            else {
                index += 1
                continue
            }
            var end = index + 1
            while end < skeleton.count, isIdentifier(skeleton[end]) { end += 1 }
            matches.append(Match(name: String(source[(index + 1)..<end]), start: index, end: end))
            index = end
        }
        return matches
    }

    private static func isIdentifierStart(_ char: Character) -> Bool {
        char == "_" || char.isLetter
    }

    private static func isIdentifier(_ char: Character) -> Bool {
        char == "_" || char.isLetter || char.isNumber
    }
}
