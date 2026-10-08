import Foundation
import NIOCore
import PostgresNIO

/// Renders binary-format temporal and numeric wire values in PostgreSQL's own text form, so the grid
/// reads like psql and the value round-trips as a SQL literal. `timestamptz` is shown in UTC (`+00`).
enum PostgresBinaryText {
    private static let microsPerSecond: Int64 = 1_000_000
    private static let secondsPerDay: Int64 = 86400
    private static let unixDaysAt2000: Int64 = 10957

    static func text(type: PostgresDataType, bytes: ByteBuffer) -> String? {
        var buffer = bytes
        switch type {
        case .timestamp:
            return buffer.readInteger(as: Int64.self).map { timestamp($0, suffix: "") }
        case .timestamptz:
            return buffer.readInteger(as: Int64.self).map { timestamp($0, suffix: "+00") }
        case .date:
            return buffer.readInteger(as: Int32.self).map(date)
        case .time:
            return buffer.readInteger(as: Int64.self).map { clock($0) }
        case .timetz:
            guard let micros = buffer.readInteger(as: Int64.self),
                  let zoneWest = buffer.readInteger(as: Int32.self) else { return nil }
            return clock(micros) + offset(seconds: -Int64(zoneWest))
        case .interval:
            guard let micros = buffer.readInteger(as: Int64.self),
                  let days = buffer.readInteger(as: Int32.self),
                  let months = buffer.readInteger(as: Int32.self) else { return nil }
            return interval(months: months, days: days, micros: micros)
        case .numeric:
            return numeric(&buffer)
        default:
            return nil
        }
    }

    private static func timestamp(_ micros: Int64, suffix: String) -> String {
        if micros == .max { return "infinity" }
        if micros == .min { return "-infinity" }
        let (seconds, fraction) = floorDivide(micros, microsPerSecond)
        let (days, secondOfDay) = floorDivide(seconds, secondsPerDay)
        let (calendarDate, era) = civil(daysSince2000: days)
        return calendarDate + " " + clock(secondOfDay * microsPerSecond + fraction) + suffix + era
    }

    private static func date(_ days: Int32) -> String {
        if days == .max { return "infinity" }
        if days == .min { return "-infinity" }
        let (calendarDate, era) = civil(daysSince2000: Int64(days))
        return calendarDate + era
    }

    private static func clock(_ micros: Int64) -> String {
        let (seconds, fraction) = floorDivide(micros, microsPerSecond)
        let base = String(format: "%02lld:%02lld:%02lld", seconds / 3600, seconds / 60 % 60, seconds % 60)
        return base + fractionDigits(fraction)
    }

    private static func fractionDigits(_ micros: Int64) -> String {
        guard micros != 0 else { return "" }
        var digits = String(format: "%06lld", micros)
        while digits.hasSuffix("0") { digits.removeLast() }
        return "." + digits
    }

    private static func offset(seconds: Int64) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let total = abs(seconds)
        var text = sign + String(format: "%02lld", total / 3600)
        if total % 3600 != 0 { text += String(format: ":%02lld", total / 60 % 60) }
        if total % 60 != 0 { text += String(format: ":%02lld", total % 60) }
        return text
    }

    // Proleptic Gregorian civil date (Hinnant's days_from_civil inverse); BC years print as Postgres does.
    private static func civil(daysSince2000: Int64) -> (String, String) {
        let z = daysSince2000 + unixDaysAt2000 + 719_468
        let era = floorDivide(z, 146_097).quotient
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        let year = yoe + era * 400 + (month <= 2 ? 1 : 0)
        let isBC = year <= 0
        let shown = isBC ? 1 - year : year
        return (String(format: "%04lld-%02lld-%02lld", shown, month, day), isBC ? " BC" : "")
    }

    // Matches IntervalStyle = postgres: "1 year 2 mons -3 days +04:05:06.5".
    private static func interval(months: Int32, days: Int32, micros: Int64) -> String {
        var parts: [String] = []
        var previousNegative = false
        for (value, unit) in [(Int64(months / 12), "year"), (Int64(months % 12), "mon"), (Int64(days), "day")]
            where value != 0 {
            let sign = previousNegative && value > 0 ? "+" : ""
            parts.append("\(sign)\(value) \(unit)\(value == 1 ? "" : "s")")
            previousNegative = value < 0
        }
        if micros != 0 || parts.isEmpty {
            let sign = micros < 0 ? "-" : (previousNegative ? "+" : "")
            let magnitude = micros.magnitude
            let seconds = Int64(magnitude / UInt64(microsPerSecond))
            let fraction = Int64(magnitude % UInt64(microsPerSecond))
            let base = String(format: "%02lld:%02lld:%02lld", seconds / 3600, seconds / 60 % 60, seconds % 60)
            parts.append(sign + base + fractionDigits(fraction))
        }
        return parts.joined(separator: " ")
    }

    // Binary numeric: ndigits, weight, sign, dscale, then base-10000 digit groups; dscale keeps trailing zeros.
    private static func numeric(_ buffer: inout ByteBuffer) -> String? {
        guard let count = buffer.readInteger(as: Int16.self),
              let weight = buffer.readInteger(as: Int16.self),
              let sign = buffer.readInteger(as: UInt16.self),
              let scale = buffer.readInteger(as: Int16.self) else { return nil }
        switch sign {
        case 0xC000: return "NaN"
        case 0xD000: return "Infinity"
        case 0xF000: return "-Infinity"
        default: break
        }
        var groups: [Int16] = []
        for _ in 0 ..< max(0, Int(count)) {
            guard let group = buffer.readInteger(as: Int16.self) else { return nil }
            groups.append(group)
        }
        func group(at index: Int) -> Int16 {
            index >= 0 && index < groups.count ? groups[index] : 0
        }
        var integer = weight < 0 ? "0" : String(group(at: 0))
        if weight > 0 {
            for index in 1 ... Int(weight) {
                integer += String(format: "%04d", group(at: index))
            }
        }
        var fraction = ""
        var index = Int(weight) + 1
        while fraction.count < Int(scale) {
            fraction += String(format: "%04d", group(at: index))
            index += 1
        }
        let digits = scale > 0 ? integer + "." + fraction.prefix(Int(scale)) : integer
        let isZero = groups.allSatisfy { $0 == 0 }
        return sign == 0x4000 && !isZero ? "-" + digits : digits
    }

    private static func floorDivide(_ value: Int64, _ divisor: Int64) -> (quotient: Int64, remainder: Int64) {
        let remainder = value % divisor
        return remainder < 0 ? (value / divisor - 1, remainder + divisor) : (value / divisor, remainder)
    }
}
