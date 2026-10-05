import Foundation

public enum BackupArchiveNaming {
    public static let fileExtension = "ktbackup"
    static let prefix = "ktstack-"

    public static func fileName(for plan: BackupPlan, at date: Date) -> String {
        "\(prefix)\(plan.shortID)-\(timestamp(date)).\(fileExtension)"
    }

    public static func belongs(_ fileName: String, to planID: UUID) -> Bool {
        let shortID = String(planID.uuidString.prefix(8)).lowercased()
        let head = "\(prefix)\(shortID)-"
        guard fileName.hasPrefix(head), fileName.hasSuffix(".\(fileExtension)") else { return false }
        let stamp = fileName.dropFirst(head.count).dropLast(fileExtension.count + 1)
        return parseTimestamp(String(stamp)) != nil
    }

    public static func createdAt(_ fileName: String) -> Date? {
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(".\(fileExtension)") else { return nil }
        let base = fileName.dropLast(fileExtension.count + 1)
        return parseTimestamp(String(base.suffix(15)))
    }

    public static func folderName(for plan: BackupPlan) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = String(plan.name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "plan-\(plan.shortID)" : cleaned
    }

    static func timestamp(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func parseTimestamp(_ text: String) -> Date? {
        formatter.date(from: text)
    }

    private static var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
