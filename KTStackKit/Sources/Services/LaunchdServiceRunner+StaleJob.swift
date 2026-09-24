import Foundation

extension LaunchdServiceRunner {
    func runsSameProgram(_ spec: LaunchAgentSpec) -> Bool {
        guard let loaded = agents.loadedProgramArguments(label) else { return true }
        return loaded == spec.programArguments
    }

    func replaceStaleJob(_ spec: LaunchAgentSpec) throws {
        guard agents.isLoadedNow(label), !runsSameProgram(spec) else { return }
        diag.log(.info, "\(kind.displayName) loaded job runs a different program; booting it out before starting the new one")
        try agents.bootout(label)
    }
}
