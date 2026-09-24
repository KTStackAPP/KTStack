import KTPluginKit

extension KTDatabasePlugin: TerminationVetoing {
    @MainActor
    public func pendingWorkDescription() -> String? {
        Self.pendingWorkDescription(pending: WorkspaceSessionRegistry.shared.pendingChangeTotal)
    }

    static func pendingWorkDescription(pending: Int) -> String? {
        guard pending > 0 else { return nil }
        return "\(pending) pending database change\(pending == 1 ? "" : "s") in open tabs will be discarded."
    }
}
