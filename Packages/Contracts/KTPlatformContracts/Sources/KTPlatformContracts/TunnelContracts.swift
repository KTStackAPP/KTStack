import Foundation

// Projection của Site theo capability tunnel: chỉ id/domain/secure mà session cần; docroot/type/phpVersion
// do platform tự resolve qua closure trong TunnelOriginConfiguring.
public struct TunnelSiteTarget: Sendable, Hashable {
    public let id: UUID
    public let domain: String
    public let secure: Bool

    public init(id: UUID, domain: String, secure: Bool) {
        self.id = id
        self.domain = domain
        self.secure = secure
    }
}

// Nginx origin vhost cho tunnel; conform trong KTStackKit. Blast radius front nginx ở lại platform.
public protocol TunnelOriginConfiguring: AnyObject, Sendable {
    // Port 80 rảnh = stack chưa chạy, tunnel sẽ trỏ vào origin chết.
    nonisolated var isFrontListening: Bool { get }
    // Chọn port ổn định theo siteID, write vhost, reload (fallback restart), đợi port listen. Trả origin port.
    @MainActor func prepareOrigin(siteID: UUID) async throws -> Int
    // Rewrite vhost với public host (sub_filter + forwarded headers + auto_prepend) rồi reload tolerant.
    @MainActor func applyPublicHost(_ host: String, siteID: UUID, port: Int, hostPrependFile: URL) async
    nonisolated func removeOrigin(siteID: UUID)            // xóa vhost + tolerant reload
    nonisolated func removeAllOrigins(reloadFront: Bool)   // reap lúc launch (true) / quit (false)
}

// Launchd mechanics cho cloudflared job; conform trong KTStackKit (wrap LaunchAgentManager).
public protocol TunnelJobManaging: Sendable {
    func bootstrapTunnelJob(label: String, binary: URL, arguments: [String], logPath: String) throws
    func bootoutTunnelJob(label: String)
    func isTunnelJobLoaded(label: String) -> Bool
    func bootoutAllTunnelJobs()   // prefix com.ktstack.tunnel.
}

// Download/install cloudflared; CloudflaredBinaryProvisioner (platform) conform.
// Không progress callback, không cancel: chưa consumer nào cần.
public protocol TunnelBinaryProviding: Sendable {
    func ensureCloudflaredInstalled() async throws -> URL
}
