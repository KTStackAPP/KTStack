import Foundation
import KTPlatformContracts

extension DNSAutomationService: DNSResolverManaging {
    public var dnsState: DNSResolverState {
        DNSResolverState(
            status: DNSResolverStatus(status),
            isBusy: isBusy,
            lastError: lastError,
            usesHelper: usesHelper,
            helperNeedsApproval: helperNeedsApproval
        )
    }

    public func dnsStates() -> AsyncStream<DNSResolverState> {
        snapshotStream { self.dnsState }
    }
}

extension DNSResolverStatus {
    init(_ status: DNSAutomationService.Status) {
        switch status {
        case .unknown: self = .unknown
        case .disabled: self = .disabled
        case .enabled: self = .enabled
        case let .conflict(proc): self = .conflict(proc)
        }
    }
}
