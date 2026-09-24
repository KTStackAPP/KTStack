import Foundation
import KTStackCore
import ServiceManagement

public struct UninstallSteps: Sendable {
    public var quiesce: @MainActor @Sendable () async -> Void
    public var disableDNS: @MainActor @Sendable () async throws -> Void
    public var disableShell: @Sendable () throws -> Void
    public var untrustCA: @Sendable () throws -> Void
    public var bootoutAll: @Sendable () -> Void
    public var removeDataRoot: @Sendable () throws -> URL?
    public var unregisterHelper: @Sendable () -> Void
    public var resolverLeft: @Sendable () -> String?

    @MainActor
    public static func live(
        paths: AppSupportPaths,
        dns: DNSAutomationService,
        mkcertBinary: URL,
        quiesce: @escaping @MainActor @Sendable () async -> Void
    ) -> UninstallSteps {
        let runner = MkcertRunner(mkcert: mkcertBinary, caroot: paths.caDir)
        let agents = LaunchAgentManager(paths: paths)
        let usesHelper = HelperIdentity.hasSigningIdentity
        let tld = dns.tld
        return UninstallSteps(
            quiesce: quiesce,
            disableDNS: { try await dns.disableAndWait() },
            disableShell: { try ShellPathManager(paths: paths).disable() },
            untrustCA: {
                try CATrustInstaller.untrust(
                    caCert: paths.caRootCert, runner: runner, helper: HelperConnection(), usesHelper: usesHelper
                )
            },
            bootoutAll: { agents.bootoutAll() },
            removeDataRoot: { try moveToTrash(paths.root) },
            unregisterHelper: {
                guard usesHelper, #available(macOS 13.0, *) else { return }
                try? SMAppService.daemon(plistName: HelperIdentity.daemonPlistName).unregister()
            },
            resolverLeft: {
                let path = DNSConstants.resolverPath(for: tld)
                return FileManager.default.fileExists(atPath: path) ? path : nil
            }
        )
    }

    static func moveToTrash(_ root: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        var trashed: NSURL?
        try FileManager.default.trashItem(at: root, resultingItemURL: &trashed)
        return trashed as URL?
    }
}
