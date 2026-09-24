import Foundation

enum NumericLiteral {
    static func cell(_ raw: String) -> Cell {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let integer = Int64(trimmed) { return .int(integer) }
        guard let double = Double(trimmed), double.isFinite, survivesDouble(trimmed, double) else {
            return .text(raw)
        }
        return .double(double)
    }

    private static func survivesDouble(_ literal: String, _ double: Double) -> Bool {
        let locale = Locale(identifier: "en_US_POSIX")
        guard let exact = Decimal(string: literal, locale: locale),
              let roundTripped = Decimal(string: String(double), locale: locale)
        else { return false }
        return exact == roundTripped
    }
}
