import Foundation

public protocol LaunchAgentManaging: Sendable {
    @discardableResult
    func writePlist(for spec: LaunchAgentSpec) throws -> URL
    func bootstrap(_ spec: LaunchAgentSpec) throws
    func kickstart(_ label: String) throws
    func bootout(_ label: String) throws
    func isLoaded(_ label: String) -> Bool
    func isLoadedNow(_ label: String) -> Bool
    func diagnostics() -> ServiceDiagnostics
}

extension LaunchAgentManager: LaunchAgentManaging {}
