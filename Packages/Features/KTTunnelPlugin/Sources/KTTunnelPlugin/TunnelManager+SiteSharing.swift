import Foundation
import KTPlatformContracts
import KTStackCore

extension TunnelManager: SiteSharing {
    public var shareStates: [UUID: SiteShareState] {
        sessions.compactMapValues(Self.shareState)
    }

    public func shareStateStream() -> AsyncStream<[UUID: SiteShareState]> {
        snapshotStream { self.shareStates }
    }

    public func startShare(_ target: TunnelSiteTarget) {
        start(target: target)
    }

    public func stopShare(siteID: UUID) {
        stop(site: siteID)
    }

    // idle/expired không có entry (row hiện lại nút Share).
    nonisolated static func shareState(_ session: TunnelSession) -> SiteShareState? {
        switch session.status {
        case .starting:
            SiteShareState(starting: true, publicURL: nil, expiresAt: session.expiresAt, error: nil)
        case let .active(url), let .activeUnverified(url):
            SiteShareState(starting: false, publicURL: url, expiresAt: session.expiresAt, error: nil)
        case let .error(message):
            SiteShareState(starting: false, publicURL: nil, expiresAt: session.expiresAt, error: message)
        case .idle, .expired:
            nil
        }
    }
}
