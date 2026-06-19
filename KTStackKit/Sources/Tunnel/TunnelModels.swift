import Foundation

public enum TunnelStatus: Equatable, Sendable {
    case idle
    case starting
    case active(URL)
    case activeUnverified(URL)
    case expired
    case error(String)

    public var publicURL: URL? {
        switch self {
        case .active(let url), .activeUnverified(let url): return url
        default: return nil
        }
    }

    public var isBusy: Bool {
        switch self {
        case .starting, .active, .activeUnverified: return true
        case .idle, .expired, .error: return false
        }
    }
}

public struct TunnelSession: Identifiable, Sendable {
    public let siteID: UUID
    public let domain: String
    public let secure: Bool
    public var status: TunnelStatus
    public let startedAt: Date

    public var id: UUID { siteID }

    public init(siteID: UUID, domain: String, secure: Bool,
                status: TunnelStatus = .starting, startedAt: Date = Date()) {
        self.siteID = siteID
        self.domain = domain
        self.secure = secure
        self.status = status
        self.startedAt = startedAt
    }
}

public enum TunnelOrigin {
    public static func url(port: Int) -> String {
        "http://127.0.0.1:\(port)"
    }

    public static func cloudflaredArguments(port: Int) -> [String] {
        ["tunnel", "--protocol", "http2", "--url", url(port: port), "--no-autoupdate"]
    }
}

public enum TrycloudflareURL {
    public static func first(in text: String) -> URL? {
        guard let range = text.range(of: "https://[a-z0-9-]+\\.trycloudflare\\.com",
                                     options: .regularExpression) else { return nil }
        return URL(string: String(text[range]))
    }
}
