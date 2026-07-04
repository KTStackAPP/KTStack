import Foundation

// Trust the local mkcert CA in the System Keychain. Prefers the privileged helper (which runs
// `security add-trusted-cert` as root over XPC), so no sudo/TTY is needed. `mkcert -install` from a
// GUI app has no TTY and its internal `sudo` fails, which is why plain install silently fails on a
// fresh Mac. Falls back to `mkcert -install` only when the signed helper is absent (dev builds).
public enum CATrustInstaller {
    public static func trust(
        caCert: URL,
        runner: MkcertRunner,
        helper: HelperConnection,
        usesHelper: Bool
    ) throws {
        if !runner.caExists { try generateCA(runner) }
        guard usesHelper else { try runner.install(); return }
        let pem = try Data(contentsOf: caCert)
        try installViaHelper(helper, pemData: pem)
    }

    // mkcert creates the CA on its first cert mint; a throwaway leaf forces generation without
    // touching the System Keychain (the trust step is what needs root, and that goes via the helper).
    private static func generateCA(_ runner: MkcertRunner) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try runner.mint(
            domain: "ktstack-ca-init.invalid",
            certFile: tmp.appendingPathComponent("c.pem"),
            keyFile: tmp.appendingPathComponent("k.pem")
        )
    }

    // Synchronous XPC call: callers already run this off the main thread. A hung helper is bounded
    // by the timeout so trust never blocks forever.
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

    private static func error(_ message: String) -> NSError {
        NSError(domain: "KTStack.catrust", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
