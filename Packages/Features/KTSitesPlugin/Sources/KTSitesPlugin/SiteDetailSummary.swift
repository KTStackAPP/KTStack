import Foundation

enum SiteDetailSummary {
    static func environment(_ vars: [String: String]) -> String {
        counted(vars.count, "variable")
    }

    static func directives(_ text: String?) -> String {
        let lines = (text ?? "").split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return counted(lines.count, "line")
    }

    static func workers(_ summary: SiteWorkersSummary) -> String {
        summary.isEmpty ? "None" : summary.label
    }

    private static func counted(_ count: Int, _ noun: String) -> String {
        switch count {
        case 0: "None"
        case 1: "1 \(noun)"
        default: "\(count) \(noun)s"
        }
    }
}
