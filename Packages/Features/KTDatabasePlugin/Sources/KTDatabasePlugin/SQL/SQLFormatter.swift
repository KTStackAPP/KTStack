import Foundation

// Định dạng SQL tại chỗ, bảo toàn nghĩa: chỉ đổi khoảng trắng, xuống dòng trước mệnh đề lớn và viết hoa keyword.
// Chuỗi, định danh backtick và comment giữ nguyên; giữa các token khác chỉ chèn 1 space khi bản gốc có space,
// nên cách viết toán tử (>=, a.b) và câu lệnh không bao giờ bị gộp hay tách.
public enum SQLFormatter {
    public static func format(_ sql: String, keywords: [String] = []) -> String {
        let parts = SQLStatementSplitter.statements(sql)
        guard !parts.isEmpty else { return sql }
        let keywordSet = Set(keywords.map { $0.uppercased() })
        let body = parts.map { formatStatement($0, keywords: keywordSet) }.joined(separator: ";\n\n")
        let keepTrailing = sql.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(";")
        return keepTrailing ? body + ";" : body
    }

    private enum Kind { case word, literal, comment, punct }

    private struct Token {
        let text: String
        let kind: Kind
        let spaceBefore: Bool
    }

    // Xuống dòng trước các từ khoá mở mệnh đề (ở paren depth 0).
    private static let breakWords: Set<String> = [
        "SELECT", "FROM", "WHERE", "GROUP", "ORDER", "HAVING", "LIMIT", "OFFSET",
        "UNION", "VALUES", "SET", "JOIN", "ON", "INSERT", "UPDATE", "DELETE", "RETURNING",
        "INNER", "LEFT", "RIGHT", "FULL", "CROSS",
    ]

    // Những từ đứng ngay trước JOIN, để không xuống dòng lần hai tại JOIN.
    private static let joinLeaders: Set<String> = ["INNER", "LEFT", "RIGHT", "FULL", "CROSS", "OUTER"]

    private static func formatStatement(_ sql: String, keywords: Set<String>) -> String {
        let tokens = lex(sql)
        guard !tokens.isEmpty else { return sql.trimmingCharacters(in: .whitespacesAndNewlines) }

        var out = ""
        var atLineStart = true
        var depth = 0
        var prevWord = ""
        var prevOpenParen = false
        var forceSpace = false
        var afterLineComment = false

        for (index, token) in tokens.enumerated() {
            let upper = token.kind == .word ? token.text.uppercased() : ""

            var lineBreak = afterLineComment
            if token.kind == .word, depth == 0, index != 0, breakWords.contains(upper) {
                lineBreak = upper == "JOIN" ? !joinLeaders.contains(prevWord) : true
            }
            if lineBreak, !atLineStart {
                out += "\n"
                atLineStart = true
                forceSpace = false
                prevOpenParen = false
            }

            if !atLineStart {
                let space: Bool
                if token.text == "," || token.text == ")" {
                    space = false
                } else if prevOpenParen {
                    space = false
                } else if forceSpace {
                    space = true
                } else {
                    space = token.spaceBefore
                }
                if space { out += " " }
            }

            out += (token.kind == .word && keywords.contains(upper)) ? upper : token.text

            atLineStart = false
            forceSpace = token.text == ","
            prevOpenParen = token.text == "("
            afterLineComment = token.kind == .comment && isLineComment(token.text)
            if token.kind == .word { prevWord = upper }
            if token.text == "(" { depth += 1 }
            if token.text == ")" { depth = max(0, depth - 1) }
        }
        return out
    }

    private static func isLineComment(_ text: String) -> Bool {
        text.hasPrefix("--") || text.hasPrefix("#")
    }

    private static func isWordChar(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "$"
    }

    private static func lex(_ sql: String) -> [Token] {
        let chars = Array(sql)
        var tokens: [Token] = []
        var index = 0
        var pendingSpace = false

        while index < chars.count {
            let character = chars[index]
            if character.isWhitespace {
                pendingSpace = true
                index += 1
                continue
            }

            if character == "'" || character == "\"" || character == "`" {
                var text = String(character)
                index += 1
                while index < chars.count {
                    let next = chars[index]
                    text.append(next)
                    index += 1
                    if next == character {
                        if index < chars.count, chars[index] == character {
                            text.append(character)
                            index += 1
                        } else {
                            break
                        }
                    }
                }
                tokens.append(Token(text: text, kind: .literal, spaceBefore: pendingSpace))
                pendingSpace = false
                continue
            }

            if (character == "-" && index + 1 < chars.count && chars[index + 1] == "-") || character == "#" {
                var text = ""
                while index < chars.count, chars[index] != "\n" {
                    text.append(chars[index])
                    index += 1
                }
                tokens.append(Token(text: text, kind: .comment, spaceBefore: pendingSpace))
                pendingSpace = false
                continue
            }

            if character == "/" && index + 1 < chars.count && chars[index + 1] == "*" {
                var text = "/*"
                index += 2
                while index < chars.count {
                    if chars[index] == "*", index + 1 < chars.count, chars[index + 1] == "/" {
                        text += "*/"
                        index += 2
                        break
                    }
                    text.append(chars[index])
                    index += 1
                }
                tokens.append(Token(text: text, kind: .comment, spaceBefore: pendingSpace))
                pendingSpace = false
                continue
            }

            if isWordChar(character) {
                var text = ""
                while index < chars.count, isWordChar(chars[index]) {
                    text.append(chars[index])
                    index += 1
                }
                tokens.append(Token(text: text, kind: .word, spaceBefore: pendingSpace))
                pendingSpace = false
                continue
            }

            tokens.append(Token(text: String(character), kind: .punct, spaceBefore: pendingSpace))
            index += 1
            pendingSpace = false
        }
        return tokens
    }
}
