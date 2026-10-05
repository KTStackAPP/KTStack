import Foundation

public enum SiteWorkerCommand {
    public static let maxLength = 1024

    public static func arguments(_ command: String) -> [String]? {
        guard command.count <= maxLength, !containsControlCharacter(command) else { return nil }
        var tokenizer = Tokenizer()
        for character in command {
            guard tokenizer.consume(character) else { return nil }
        }
        guard let words = tokenizer.finish(), !words.isEmpty else { return nil }
        return words
    }

    public static func render(_ arguments: [String]) -> String {
        arguments.map(quoted).joined(separator: " ")
    }

    private static func quoted(_ word: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:=,@%+")
        if !word.isEmpty, word.unicodeScalars.allSatisfy({ safe.contains($0) }) { return word }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func containsControlCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { ($0.value < 0x20 && $0 != "\t") || $0.value == 0x7F }
    }

    private struct Tokenizer {
        private enum Quote { case none, single, double }

        private var words: [String] = []
        private var current = ""
        private var hasWord = false
        private var quote = Quote.none
        private var escaping = false

        mutating func consume(_ character: Character) -> Bool {
            if escaping {
                current.append(character)
                escaping = false
                return true
            }
            switch quote {
            case .single:
                if character == "'" { quote = .none } else { current.append(character) }
            case .double:
                consumeDoubleQuoted(character)
            case .none:
                consumeUnquoted(character)
            }
            return true
        }

        private mutating func consumeDoubleQuoted(_ character: Character) {
            switch character {
            case "\"": quote = .none
            case "\\": escaping = true
            default: current.append(character)
            }
        }

        private mutating func consumeUnquoted(_ character: Character) {
            switch character {
            case " ", "\t":
                flush()
            case "'":
                quote = .single
                hasWord = true
            case "\"":
                quote = .double
                hasWord = true
            case "\\":
                escaping = true
                hasWord = true
            default:
                current.append(character)
                hasWord = true
            }
        }

        private mutating func flush() {
            guard hasWord else { return }
            words.append(current)
            current = ""
            hasWord = false
        }

        mutating func finish() -> [String]? {
            guard quote == .none, !escaping else { return nil }
            flush()
            return words
        }
    }
}
