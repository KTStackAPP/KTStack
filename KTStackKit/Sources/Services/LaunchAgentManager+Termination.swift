import Foundation

extension LaunchAgentManager {
    func writeBootstrapPlist(for spec: LaunchAgentSpec) throws -> URL {
        guard !AppTermination.isTerminating else { throw AppTermination.Refused(label: spec.label) }
        return try writePlist(for: spec)
    }
}
