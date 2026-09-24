public protocol TerminationVetoing {
    @MainActor
    func pendingWorkDescription() -> String?
}
