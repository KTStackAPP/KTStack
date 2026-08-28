import Foundation

// Phân loại từng câu SQL là đọc hay ghi để chặn ghi ở kết nối read-only (UI chặn sớm; driver vẫn là ranh giới thật).
public enum SQLStatementKind: Equatable {
    case read
    case write

    private static let readLeaders: Set<String> = [
        "SELECT", "WITH", "SHOW", "EXPLAIN", "DESCRIBE", "DESC",
        "PRAGMA", "USE", "SET", "TABLE", "VALUES", "ANALYZE",
    ]

    public static func classify(_ statement: String) -> SQLStatementKind {
        guard let word = leadingWord(statement) else { return .read }
        guard readLeaders.contains(word) else { return .write }
        // WITH có thể bọc INSERT/UPDATE/DELETE (data-modifying CTE): coi là ghi.
        if word == "WITH",
           statement.range(of: #"\b(INSERT|UPDATE|DELETE|MERGE)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .write
        }
        return .read
    }

    public static func hasWrite(_ sql: String) -> Bool {
        SQLStatementSplitter.statements(sql).contains { classify($0) == .write }
    }

    private static func leadingWord(_ statement: String) -> String? {
        guard let match = statement.range(of: #"[A-Za-z]+"#, options: .regularExpression) else { return nil }
        return statement[match].uppercased()
    }
}
