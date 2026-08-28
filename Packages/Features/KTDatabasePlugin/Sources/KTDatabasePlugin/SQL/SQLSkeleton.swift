import Foundation

// Quét SQL thành "skeleton" cùng độ dài: chuỗi, định danh backtick và comment bị thay bằng khoảng trắng.
// Nhờ giữ nguyên vị trí ký tự, mọi consumer (auto-limit, splitter, param binder) có thể cắt lại text gốc theo chỉ số.
public enum SQLSkeleton {
    public struct Scan: Equatable {
        public let text: String
        public let isWellFormed: Bool
    }

    private enum Mode {
        case normal, single, double, backtick, lineComment, blockComment
    }

    public static func scan(_ sql: String) -> Scan {
        var mode: Mode = .normal
        var output = ""
        output.reserveCapacity(sql.count)
        let characters = Array(sql)
        var index = 0

        func peek(_ offset: Int) -> Character? {
            let target = index + offset
            return target < characters.count ? characters[target] : nil
        }

        while index < characters.count {
            let character = characters[index]
            switch mode {
            case .normal:
                if character == "'" { mode = .single; output.append(" ") }
                else if character == "\"" { mode = .double; output.append(" ") }
                else if character == "`" { mode = .backtick; output.append(" ") }
                else if character == "-", peek(1) == "-" { mode = .lineComment; output.append("  "); index += 1 }
                else if character == "#" { mode = .lineComment; output.append(" ") }
                else if character == "/", peek(1) == "*" { mode = .blockComment; output.append("  "); index += 1 }
                else { output.append(character) }
            case .single:
                output.append(" ")
                if character == "'" {
                    if peek(1) == "'" { output.append(" "); index += 1 } else { mode = .normal }
                }
            case .double:
                output.append(" ")
                if character == "\"" {
                    if peek(1) == "\"" { output.append(" "); index += 1 } else { mode = .normal }
                }
            case .backtick:
                output.append(" ")
                if character == "`" {
                    if peek(1) == "`" { output.append(" "); index += 1 } else { mode = .normal }
                }
            case .lineComment:
                if character == "\n" { mode = .normal; output.append(character) } else { output.append(" ") }
            case .blockComment:
                output.append(" ")
                if character == "*", peek(1) == "/" { output.append(" "); index += 1; mode = .normal }
            }
            index += 1
        }

        let wellFormed = (mode == .normal || mode == .lineComment)
        return Scan(text: output, isWellFormed: wellFormed)
    }
}
