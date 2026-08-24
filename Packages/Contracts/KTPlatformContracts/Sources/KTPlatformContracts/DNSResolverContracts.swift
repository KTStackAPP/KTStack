import Foundation

public enum DNSResolverStatus: Sendable, Equatable {
    case unknown, disabled, enabled, conflict(String)
}

public struct DNSResolverState: Sendable, Equatable {
    public var status: DNSResolverStatus
    public var isBusy: Bool
    public var lastError: String?
    public var usesHelper: Bool
    public var helperNeedsApproval: Bool

    public init(
        status: DNSResolverStatus,
        isBusy: Bool,
        lastError: String?,
        usesHelper: Bool,
        helperNeedsApproval: Bool
    ) {
        self.status = status
        self.isBusy = isBusy
        self.lastError = lastError
        self.usesHelper = usesHelper
        self.helperNeedsApproval = helperNeedsApproval
    }
}

public protocol DNSResolverManaging: AnyObject {
    @MainActor var dnsState: DNSResolverState { get }
    @MainActor func dnsStates() -> AsyncStream<DNSResolverState>
    @MainActor func enable()
    @MainActor func reset()
    @MainActor func refresh()
}
