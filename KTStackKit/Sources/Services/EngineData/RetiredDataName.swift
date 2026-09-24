import Foundation

enum RetiredDataName {
    static func stamp(_ date: Date) -> String {
        formatter().string(from: date)
    }

    static func parse(_ name: String) -> (version: String, removedAt: Date)? {
        let pattern = #"^(.+)-(\d{8}-\d{6})(?:-\d+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let versionRange = Range(match.range(at: 1), in: name),
              let stampRange = Range(match.range(at: 2), in: name),
              let date = formatter().date(from: String(name[stampRange]))
        else { return nil }
        return (String(name[versionRange]), date)
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
