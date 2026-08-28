import Foundation

// Tách một văn bản SQL thành các câu lệnh theo dấu ; ở mức top-level.
// Dấu ; nằm trong chuỗi, định danh backtick hay comment không tách câu (dựa trên SQLSkeleton).
// Custom DELIMITER (stored program) không thuộc phạm vi MVP; xem Risk Assessment phase 5.
public enum SQLStatementSplitter {
    public struct Statement: Equatable {
        public let sql: String
        public let range: Range<Int>

        public init(sql: String, range: Range<Int>) {
            self.sql = sql
            self.range = range
        }
    }

    public static func split(_ sql: String) -> [Statement] {
        let source = Array(sql)
        let skeleton = Array(SQLSkeleton.scan(sql).text)
        guard source.count == skeleton.count else { return fallbackSingle(sql) }

        var statements: [Statement] = []
        var segmentStart = 0
        var index = 0
        while index < skeleton.count {
            if skeleton[index] == ";" {
                append(&statements, source: source, skeleton: skeleton, from: segmentStart, to: index)
                segmentStart = index + 1
            }
            index += 1
        }
        append(&statements, source: source, skeleton: skeleton, from: segmentStart, to: skeleton.count)
        return statements
    }

    // Chỉ lấy văn bản từng câu; dùng cho guard và các consumer không cần range.
    public static func statements(_ sql: String) -> [String] {
        split(sql).map(\.sql)
    }

    private static func append(
        _ out: inout [Statement],
        source: [Character],
        skeleton: [Character],
        from: Int,
        to: Int
    ) {
        var lo = from
        var hi = to
        while lo < hi, skeleton[lo].isWhitespace { lo += 1 }
        while hi > lo, skeleton[hi - 1].isWhitespace { hi -= 1 }
        guard lo < hi else { return }
        out.append(Statement(sql: String(source[lo..<hi]), range: lo..<hi))
    }

    private static func fallbackSingle(_ sql: String) -> [Statement] {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [Statement(sql: trimmed, range: 0..<sql.count)]
    }
}
