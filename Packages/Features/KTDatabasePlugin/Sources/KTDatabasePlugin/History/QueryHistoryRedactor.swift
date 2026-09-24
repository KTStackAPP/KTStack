import Foundation

enum QueryHistoryRedactor {
    static let maxStoredLength = 64 * 1024

    private static let secret = #"('(?:[^'\\]|\\.|'')*'|"(?:[^"\\]|\\.)*")"#
    private static let pattern = #"(?i)(\bIDENTIFIED\s+(?:WITH\s+\w+\s+)?(?:BY|AS)\s+|\bPASSWORD\s*(?:=\s*|\(\s*)?)"# + secret

    static func redact(_ sql: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return sql }
        let range = NSRange(sql.startIndex..., in: sql)
        return regex.stringByReplacingMatches(in: sql, range: range, withTemplate: "$1'***'")
    }
}
