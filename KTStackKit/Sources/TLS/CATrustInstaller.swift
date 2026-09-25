import CryptoKit
import Foundation
import KTStackCore
import Security

public enum CATrustInstaller {
    public static func trust(
        caCert: URL,
        runner: MkcertRunner,
        helper: HelperConnection,
        usesHelper: Bool
    ) throws {
        if !runner.caExists { try generateCA(runner) }
        guard usesHelper else {
            do {
                try runner.install()
            } catch {
                if !installUserTrust(caCert: caCert) {
                    throw error
                }
            }
            return
        }
        let pem = try Data(contentsOf: caCert)
        try installViaHelper(helper, pemData: pem)
    }

    public static func untrust(
        caCert: URL,
        runner: MkcertRunner,
        helper: HelperConnection,
        usesHelper: Bool
    ) throws {
        guard runner.caExists else { return }
        removeUserTrust(caCert: caCert)
        guard usesHelper else {
            do {
                try runner.uninstall()
            } catch {
                if !isItemNotFoundError(error) { throw error }
            }
            return
        }
        guard let pem = try? Data(contentsOf: caCert),
              let der = CertMinter.pemToDER(pem) else {
            do {
                try runner.uninstall()
            } catch {
                if !isItemNotFoundError(error) { throw error }
            }
            return
        }
        let sha1 = Insecure.SHA1.hash(data: der).map { String(format: "%02X", $0) }.joined()
        try removeViaHelper(helper, certSHA1: sha1)
    }
    private static func generateCA(_ runner: MkcertRunner) throws {
        if RestrictedRootCA.isEnabled() {
            return try RestrictedRootCA.generate(
                caDir: runner.caroot,
                tlds: RestrictedRootCA.permittedTLDs(including: RestrictedRootCA.currentTLD())
            )
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try runner.mint(
            domain: "ktstack-ca-init.invalid",
            certFile: tmp.appendingPathComponent("c.pem"),
            keyFile: tmp.appendingPathComponent("k.pem")
        )
    }

    private static func installViaHelper(_ helper: HelperConnection, pemData: Data) throws {
        let sem = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var resumed = false
        var result: (ok: Bool, message: String?) = (false, "Privileged helper is not available.")
        let finish: (Bool, String?) -> Void = { ok, msg in
            lock.lock(); defer { lock.unlock() }
            guard !resumed else { return }
            resumed = true; result = (ok, msg); sem.signal()
        }

        guard let proxy = helper.remoteProxy({ finish(false, $0.localizedDescription) }) else {
            throw error("Privileged helper is not available.")
        }
        proxy.installRootCA(pemData: pemData) { ok, msg in finish(ok, msg) }

        if sem.wait(timeout: .now() + 25) == .timedOut {
            throw error("The privileged helper did not respond in time.")
        }
        guard result.ok else { throw error(result.message ?? "Could not trust the local CA.") }
    }
    private static func removeViaHelper(_ helper: HelperConnection, certSHA1: String) throws {
        let sem = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var resumed = false
        var result: (ok: Bool, message: String?) = (false, "Privileged helper is not available.")
        let finish: (Bool, String?) -> Void = { ok, msg in
            lock.lock(); defer { lock.unlock() }
            guard !resumed else { return }
            resumed = true; result = (ok, msg); sem.signal()
        }

        guard let proxy = helper.remoteProxy({ finish(false, $0.localizedDescription) }) else {
            throw error("Privileged helper is not available.")
        }
        proxy.removeRootCA(certSHA1: certSHA1) { ok, msg in finish(ok, msg) }

        if sem.wait(timeout: .now() + 25) == .timedOut {
            throw error("The privileged helper did not respond in time.")
        }
        guard result.ok else { throw error(result.message ?? "Could not remove the local CA.") }
    }

    private static func installUserTrust(caCert: URL) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["add-trusted-cert", "-r", "trustRoot", "-p", "ssl", "-p", "basic", caCert.path]
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func removeUserTrust(caCert: URL) {
        if let pem = try? Data(contentsOf: caCert),
           let der = CertMinter.pemToDER(pem),
           let cert = SecCertificateCreateWithData(nil, der as CFData) {
            SecTrustSettingsRemoveTrustSettings(cert, .user)
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["remove-trusted-cert", caCert.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try? proc.run()
        proc.waitUntilExit()
    }

    private static func isItemNotFoundError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not be found") || message.contains("not found") || message.contains("-25300")
    }
    private static func error(_ message: String) -> NSError {
        NSError(domain: "KTStack.catrust", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
