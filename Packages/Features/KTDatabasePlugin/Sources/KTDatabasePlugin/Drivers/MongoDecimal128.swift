import Foundation

struct MongoDecimal128: Equatable, Sendable {
    let low: UInt64
    let high: UInt64

    private static let exponentBias = 6176
    private static let maxExponent = 6111
    private static let minExponent = -6176
    private static let maxDigits = 34
    private static let maxCoefficient = (high: UInt64(0x0001_ED09_BEAD_87C0), low: UInt64(0x378D_8E63_FFFF_FFFF))

    init(low: UInt64, high: UInt64) {
        self.low = low
        self.high = high
    }

    init?(string: String) {
        let text = string.trimmingCharacters(in: .whitespaces)
        var body = Substring(text)
        let negative = body.first == "-"
        if body.first == "-" || body.first == "+" { body = body.dropFirst() }
        let sign: UInt64 = negative ? 1 << 63 : 0
        switch body.lowercased() {
        case "inf", "infinity": self.init(low: 0, high: sign | 0x7800_0000_0000_0000); return
        case "nan": self.init(low: 0, high: 0x7C00_0000_0000_0000); return
        default: break
        }
        guard let parsed = Self.parse(body), let normalized = Self.normalize(parsed.digits, parsed.exponent) else {
            return nil
        }
        let coefficient = normalized.coefficient
        self.init(low: coefficient.low, high: sign | (UInt64(normalized.biased) << 49) | coefficient.high)
    }

    var description: String {
        let negative = high >> 63 == 1
        let combination = (high >> 58) & 0x1F
        if combination == 0x1F { return "NaN" }
        if combination == 0x1E { return negative ? "-Infinity" : "Infinity" }
        let biased: Int
        var coefficient: (high: UInt64, low: UInt64)
        if combination >> 3 == 0b11 {
            biased = Int((high >> 47) & 0x3FFF)
            coefficient = (0, 0)
        } else {
            biased = Int((high >> 49) & 0x3FFF)
            coefficient = (high & 0x1_FFFF_FFFF_FFFF, low)
            if Self.greater(coefficient, Self.maxCoefficient) { coefficient = (0, 0) }
        }
        let text = Self.format(digits: Self.decimalDigits(coefficient), exponent: biased - Self.exponentBias)
        return negative ? "-" + text : text
    }

    private static func parse(_ body: Substring) -> (digits: [UInt8], exponent: Int)? {
        let parts = body.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "e" || $0 == "E" })
        guard parts.count <= 2, let mantissa = parts.first else { return nil }
        var exponent = 0
        if parts.count == 2 {
            guard let value = Int(parts[1]), abs(value) < 100_000 else { return nil }
            exponent = value
        }
        var digits: [UInt8] = []
        var seenPoint = false
        for character in mantissa {
            if character == ".", !seenPoint { seenPoint = true; continue }
            guard let digit = character.wholeNumberValue, character.isASCII else { return nil }
            digits.append(UInt8(digit))
            if seenPoint { exponent -= 1 }
        }
        guard !digits.isEmpty else { return nil }
        while digits.count > 1, digits.first == 0 { digits.removeFirst() }
        return (digits, exponent)
    }

    private static func normalize(
        _ input: [UInt8],
        _ inputExponent: Int
    ) -> (coefficient: (high: UInt64, low: UInt64), biased: Int)? {
        var digits = input
        var exponent = inputExponent
        let isZero = digits == [0]
        while digits.count > maxDigits {
            guard digits.last == 0 else { return nil }
            digits.removeLast()
            exponent += 1
        }
        if isZero {
            exponent = min(max(exponent, minExponent), maxExponent)
        }
        while exponent > maxExponent, digits.count < maxDigits {
            digits.append(0)
            exponent -= 1
        }
        while exponent < minExponent, digits.count > 1, digits.last == 0 {
            digits.removeLast()
            exponent += 1
        }
        guard (minExponent...maxExponent).contains(exponent) else { return nil }
        var coefficient: (high: UInt64, low: UInt64) = (0, 0)
        for digit in digits {
            let product = coefficient.low.multipliedFullWidth(by: 10)
            let (low, carry) = product.low.addingReportingOverflow(UInt64(digit))
            coefficient = (coefficient.high &* 10 &+ product.high &+ (carry ? 1 : 0), low)
        }
        return (coefficient, exponent + exponentBias)
    }

    private static func greater(_ lhs: (high: UInt64, low: UInt64), _ rhs: (high: UInt64, low: UInt64)) -> Bool {
        lhs.high != rhs.high ? lhs.high > rhs.high : lhs.low > rhs.low
    }

    private static func decimalDigits(_ value: (high: UInt64, low: UInt64)) -> String {
        var limbs = [UInt32(value.high >> 32), UInt32(value.high & 0xFFFF_FFFF), UInt32(value.low >> 32), UInt32(value.low & 0xFFFF_FFFF)]
        var chunks: [UInt32] = []
        repeat {
            var remainder: UInt64 = 0
            for index in limbs.indices {
                let current = (remainder << 32) | UInt64(limbs[index])
                limbs[index] = UInt32(current / 1_000_000_000)
                remainder = current % 1_000_000_000
            }
            chunks.append(UInt32(remainder))
        } while limbs.contains { $0 != 0 }
        var text = String(chunks.removeLast())
        for chunk in chunks.reversed() {
            let part = String(chunk)
            text += String(repeating: "0", count: 9 - part.count) + part
        }
        return text
    }

    private static func format(digits: String, exponent: Int) -> String {
        let adjusted = exponent + digits.count - 1
        if exponent > 0 || adjusted < -6 {
            let head = String(digits.prefix(1))
            let tail = digits.count > 1 ? "." + digits.dropFirst() : ""
            return head + tail + "E" + (adjusted >= 0 ? "+" : "") + String(adjusted)
        }
        if exponent == 0 { return digits }
        let point = digits.count + exponent
        if point > 0 {
            return String(digits.prefix(point)) + "." + String(digits.dropFirst(point))
        }
        return "0." + String(repeating: "0", count: -point) + digits
    }
}
