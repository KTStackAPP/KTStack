import Foundation

public struct CATrustState: Sendable, Equatable {
    public var exists: Bool
    public var trusted: Bool

    public init(exists: Bool, trusted: Bool) {
        self.exists = exists
        self.trusted = trusted
    }
}

public protocol CATrustProviding: AnyObject {
    @MainActor var caTrustState: CATrustState { get }
    @MainActor func caTrustStates() -> AsyncStream<CATrustState>
    @MainActor func refreshTrust() async
}
