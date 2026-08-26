import Foundation

// Kết quả validate env var của site; plugin map sang message, registry chặn khi ghi.
public enum SiteEnvVarError: Equatable, Sendable {
    case invalidKey(String)
    case reservedKey(String)
    case invalidValue(String)
}

// Env var per-site cho PHP (fastcgi_param/SetEnv) và Node (export). Validation ở Core để
// plugin báo inline và registry chặn khi ghi dùng chung một luật, như ProxyTarget.
public enum SiteEnvVars {
    // Các fastcgi param writer đang set + HTTPS + PORT: user key trùng sẽ đè param của app nên bị từ chối.
    public static let reservedKeys: Set<String> = [
        "SCRIPT_FILENAME", "QUERY_STRING", "REQUEST_METHOD", "CONTENT_TYPE",
        "CONTENT_LENGTH", "REQUEST_URI", "DOCUMENT_URI", "DOCUMENT_ROOT",
        "SERVER_PROTOCOL", "GATEWAY_INTERFACE", "SERVER_SOFTWARE", "HTTPS",
        "REMOTE_ADDR", "REMOTE_PORT", "SERVER_ADDR", "SERVER_PORT",
        "SERVER_NAME", "PORT",
    ]

    public static func validate(_ env: [String: String]) -> SiteEnvVarError? {
        for (key, value) in env {
            guard isValidKey(key) else { return .invalidKey(key) }
            if reservedKeys.contains(key) { return .reservedKey(key) }
            if hasForbiddenValueChar(value) { return .invalidValue(key) }
        }
        return nil
    }

    // Render ổn định: sort theo key nên output config không đổi giữa các lần ghi.
    public static func sorted(_ env: [String: String]) -> [(key: String, value: String)] {
        env.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
    }

    // ^[A-Za-z_][A-Za-z0-9_]*$
    private static func isValidKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        for (index, ch) in key.enumerated() {
            let isAlpha = ch.isASCII && ch.isLetter
            let isDigit = ch.isASCII && ch.isNumber
            if index == 0 {
                if !(isAlpha || ch == "_") { return false }
            } else if !(isAlpha || isDigit || ch == "_") {
                return false
            }
        }
        return true
    }

    private static func hasForbiddenValueChar(_ value: String) -> Bool {
        value.unicodeScalars.contains { $0 == "\n" || $0 == "\r" || $0 == "\0" }
    }
}
