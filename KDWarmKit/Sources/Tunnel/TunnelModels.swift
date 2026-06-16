import Foundation

public enum TunnelStatus: Equatable, Sendable {
    case idle
    case starting
    case active(URL)
    case expired
    case error(String)

    public var publicURL: URL? {
        if case let .active(url) = self { return url }
        return nil
    }

    public var isBusy: Bool {
        switch self {
        case .starting, .active: return true
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
    public static func url(secure: Bool) -> String {
        secure ? "https://127.0.0.1:443" : "http://127.0.0.1:80"
    }

    public static func cloudflaredArguments(secure: Bool, domain: String) -> [String] {
        var args = ["tunnel", "--url", url(secure: secure)]
        if secure { args.append("--no-tls-verify") }
        args += ["--http-host-header", domain, "--no-autoupdate"]
        return args
    }
}

public enum TrycloudflareURL {
    public static func first(in text: String) -> URL? {
        guard let range = text.range(of: "https://[a-z0-9-]+\\.trycloudflare\\.com",
                                     options: .regularExpression) else { return nil }
        return URL(string: String(text[range]))
    }
}
