import Foundation
import KTStackCore

extension LocalServerController {
    var skippedEnvWarning: String? {
        let affected = registry.sites.filter { !SiteEnvVars.skippedKeys($0.envVars).isEmpty }.map(\.domain)
        guard !affected.isEmpty else { return nil }
        return "Some environment values contain characters nginx can't accept (\", $ or \\) and were left out for "
            + affected.sorted().joined(separator: ", ") + ". Edit them in Site Settings."
    }

    func finishDirectivesSave() {
        isBusy = false
        guard pendingReconcile else { return }
        pendingReconcile = false
        reconcile()
    }
}
