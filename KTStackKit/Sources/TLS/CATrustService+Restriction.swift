import Foundation
import KTStackCore

public extension CATrustService {
    var currentTLDCovered: Bool {
        coverage.covers(RestrictedRootCA.currentTLD())
    }

    func regenerateRestrictedCA(onDone: (@Sendable @MainActor () -> Void)? = nil) {
        let runner = runner, helper = helper, usesHelper = usesHelper
        let caCert = paths.caRootCert, caDir = paths.caDir
        let tlds = RestrictedRootCA.permittedTLDs(including: RestrictedRootCA.currentTLD())
        run({
            let staged = try RestrictedRootCA.stage(caDir: caDir, tlds: tlds)
            defer { try? FileManager.default.removeItem(at: staged) }
            try CATrustInstaller.untrust(caCert: caCert, runner: runner, helper: helper, usesHelper: usesHelper)
            try RestrictedRootCA.install(staged: staged, caDir: caDir)
            try CATrustInstaller.trust(caCert: caCert, runner: runner, helper: helper, usesHelper: usesHelper)
        }, completion: { ok in
            if ok { onDone?() }
        })
    }
}
