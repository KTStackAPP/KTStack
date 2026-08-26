import Foundation

// Nguồn duy nhất cho regex nhãn DNS; Kit's isValidDomain gọi lại để khỏi lệch.
public enum HostSyntax {
    static let label = "[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?"

    // 1+ nhãn: chấp nhận "localhost", "api.example.com", IPv4 literal.
    public static func isValidHost(_ host: String) -> Bool {
        host.range(of: "^\(label)(\\.\(label))*$", options: .regularExpression) != nil
    }

    // 2+ nhãn: site domain phải có dấu chấm (".test").
    public static func isValidDomain(_ domain: String) -> Bool {
        domain.range(of: "^\(label)(\\.\(label))+$", options: .regularExpression) != nil
    }
}
