import Foundation

/// Dựng khối text dán thẳng vào GitHub issue. Chỉ lấy các trường trong allowlist dưới đây và
/// thay mọi path dưới home bằng ~ để report không lộ tên user.
public struct DoctorReportFormatter: Sendable {
    private let homePath: String

    public init(homePath: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.homePath = homePath
    }

    public func text(for report: DoctorReport) -> String {
        var lines = ["KTStack Doctor report"]
        lines.append("Generated: \(Self.stamp(report.generatedAt))")

        let env = report.environment
        lines.append("App: \(env.appVersion) (\(env.appBuild))")
        lines.append("macOS: \(env.systemVersion), arch: \(env.architecture), TLD: .\(env.tld)")
        lines.append("Overall: \(report.status.rawValue.uppercased())")
        lines.append("")

        for check in report.checks {
            lines.append("[\(check.status.rawValue.uppercased())] \(check.title)")
            lines.append("  \(check.detail)")
            if let remedy = check.remedy { lines.append("  Fix: \(remedy)") }
        }

        return redact(lines.joined(separator: "\n"))
    }

    func redact(_ text: String) -> String {
        guard !homePath.isEmpty else { return text }
        return text.replacingOccurrences(of: homePath, with: "~")
    }

    private static let stampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func stamp(_ date: Date) -> String {
        stampFormatter.string(from: date)
    }
}
