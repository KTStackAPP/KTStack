import Combine
import CryptoKit
import Foundation
import KTStackCore
import Security
@MainActor
public final class CATrustService: ObservableObject {
    public enum Status: Equatable, Sendable {
        case notInstalled
        case untrusted
        case trusted
    }

    @Published public private(set) var status: Status = .notInstalled
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    public let usesHelper = HelperIdentity.hasSigningIdentity

    public nonisolated let runner: MkcertRunner
    private nonisolated let paths: AppSupportPaths
    private nonisolated let helper = HelperConnection()

    public init(paths: AppSupportPaths, mkcertBinary: URL) {
        self.paths = paths
        runner = MkcertRunner(mkcert: mkcertBinary, caroot: paths.caDir)
        refresh()
    }

    public var isTrusted: Bool {
        status == .trusted
    }

    public func refresh() {
        guard runner.caExists else { status = .notInstalled; return }
        status = Self.isTrustedInSystemKeychain(caCert: paths.caRootCert) ? .trusted : .untrusted
    }

    public func refreshAsync() async {
        guard runner.caExists else { status = .notInstalled; return }
        let caCert = paths.caRootCert
        let trusted = await Task.detached { Self.isTrustedInSystemKeychain(caCert: caCert) }.value
        status = trusted ? .trusted : .untrusted
    }

    public func install() {
        let runner = runner, helper = helper, usesHelper = usesHelper, caCert = paths.caRootCert
        run { try CATrustInstaller.trust(caCert: caCert, runner: runner, helper: helper, usesHelper: usesHelper) }
    }

    public func untrust() {
        let runner = runner, helper = helper, usesHelper = usesHelper, caCert = paths.caRootCert
        run { try CATrustInstaller.untrust(caCert: caCert, runner: runner, helper: helper, usesHelper: usesHelper) }
    }

    public func ensureTrusted() throws {
        guard !isTrusted else { return }
        try CATrustInstaller.trust(caCert: paths.caRootCert, runner: runner, helper: helper, usesHelper: usesHelper)
    }

    private func run(_ work: @escaping @Sendable () throws -> Void) {
        guard !isBusy else { return }
        isBusy = true; lastError = nil
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do { try work() } catch { failure = error.localizedDescription }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure }
                self.refresh()
            }
        }
    }

    public nonisolated static func isTrustedInSystemKeychain(caCert: URL) -> Bool {
        guard let pem = try? Data(contentsOf: caCert),
              let der = CertMinter.pemToDER(pem),
              let cert = SecCertificateCreateWithData(nil, der as CFData) else {
            return false
        }
        var trust: SecTrust?
        if SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust) == errSecSuccess,
           let trust,
           SecTrustEvaluateWithError(trust, nil) {
            return true
        }
        var settings: CFArray?
        if SecTrustSettingsCopyTrustSettings(cert, .admin, &settings) == errSecSuccess {
            return true
        }
        if SecTrustSettingsCopyTrustSettings(cert, .user, &settings) == errSecSuccess {
            return true
        }
        return false
    }
}
