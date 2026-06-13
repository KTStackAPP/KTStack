import Foundation

/// One-time `sudo` path to enable `.test` DNS WITHOUT the SMAppService helper — the safety net for
/// when the user misses/declines the background-item approval. It performs the SAME root operations
/// as the helper (copy dnsmasq to a root dir, write config + `/etc/resolver/test` + a launchd daemon
/// plist, bootstrap dnsmasq), sourced from the same `DNSConstants`, so behaviour can't diverge.
///
/// Security: every value interpolated into the root-run script is single-quote-escaped (`shellQuote`),
/// and the script is staged in a freshly-created `0700` per-run directory (no fixed, predictable path
/// another same-user process could swap before root reads it).
public struct SudoFallbackInstaller {
    /// The bundled dnsmasq to copy into the root support dir (`KDWarm.app/Contents/Resources/bin/dnsmasq`).
    public let bundledDnsmasq: URL
    /// The live dev TLD (configurable, Phase 5). The install/uninstall/reset scripts operate on this
    /// TLD; `setTLDScript` takes explicit old/new so a change can clean up the previous resolver.
    public let tld: String

    public init(bundledDnsmasq: URL, tld: String = AppPreferences.defaultTLD) {
        self.bundledDnsmasq = bundledDnsmasq
        self.tld = tld
    }

    /// Root install script — idempotent: re-running re-bootstraps with the current config.
    public func installScript() -> String { "#!/bin/bash\nset -euo pipefail\n" + installBody(tld: tld) }

    /// Root uninstall script — full cleanup (reverses installScript).
    public func uninstallScript() -> String { "#!/bin/bash\nset -uo pipefail\n" + uninstallBody(tld: tld) }

    /// Combined reset: uninstall then install in ONE root invocation (single admin prompt).
    public func resetScript() -> String {
        "#!/bin/bash\nset -uo pipefail\n" + uninstallBody(tld: tld) + "\nset -e\n" + installBody(tld: tld)
    }

    /// Combined TLD change in ONE root invocation (single admin prompt): remove the OLD resolver,
    /// then re-bootstrap dnsmasq + write the NEW resolver for `new`, then flush the DNS cache. The
    /// mirror of `HelperDNSManager.setTLD` for the no-helper path. Removing the old resolver first is
    /// the critical step — an orphaned `/etc/resolver/<old>` would keep poisoning system DNS.
    public func setTLDScript(old: String, new: String) -> String {
        let removeOld = old == new ? "" : "rm -f \(q(DNSConstants.resolverPath(for: old)))\n"
        return "#!/bin/bash\nset -euo pipefail\n"
            + removeOld
            + installBody(tld: new)
            + "\n/usr/bin/dscacheutil -flushcache || true\n"
    }

    // MARK: - Script bodies (no shebang) — composed by the public scripts above.

    private func installBody(tld: String) -> String {
        """
        mkdir -p \(q("\(DNSConstants.supportDir)/bin"))
        cp \(q(bundledDnsmasq.path)) \(q(DNSConstants.dnsmasqBinaryPath))
        chmod 0755 \(q(DNSConstants.dnsmasqBinaryPath))

        cat > \(q(DNSConstants.dnsmasqConfPath)) <<'KDWARM_CONF'
        \(DNSConstants.dnsmasqConf(for: tld))
        KDWARM_CONF

        mkdir -p /etc/resolver
        cat > \(q(DNSConstants.resolverPath(for: tld))) <<'KDWARM_RESOLVER'
        \(DNSConstants.resolverContents)KDWARM_RESOLVER

        cat > \(q(DNSConstants.daemonPlistPath)) <<'KDWARM_PLIST'
        \(DNSConstants.daemonPlist)
        KDWARM_PLIST
        chmod 0644 \(q(DNSConstants.daemonPlistPath))

        launchctl bootout system/\(DNSConstants.daemonLabel) 2>/dev/null || true
        launchctl bootstrap system \(q(DNSConstants.daemonPlistPath))
        echo "KDWarm DNS enabled — *.\(tld) resolves to 127.0.0.1"
        """
    }

    private func uninstallBody(tld: String) -> String {
        """
        launchctl bootout system/\(DNSConstants.daemonLabel) 2>/dev/null || true
        rm -f \(q(DNSConstants.resolverPath(for: tld))) \(q(DNSConstants.daemonPlistPath)) \(q(DNSConstants.dnsmasqConfPath))
        rm -f \(q(DNSConstants.dnsmasqBinaryPath))
        echo "KDWarm DNS disabled — *.\(tld) no longer resolves locally"
        """
    }

    /// Single-quote-escape a value for safe interpolation into the root shell script.
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    private func q(_ value: String) -> String { Self.shellQuote(value) }

    // MARK: - Staging + execution

    /// Write all three scripts into a FRESH `0700` per-run dir (no predictable path to swap), and
    /// return their URLs.
    @discardableResult
    public func writeScripts(to dir: URL) throws -> (install: URL, uninstall: URL, reset: URL) {
        // Refuse before staging any root-run script: `tld` renders into a dnsmasq heredoc body that
        // cannot be shell-quoted, so a crafted value (newline → injected directives) must be rejected
        // here — input validation is the only correct control for the heredoc body.
        _ = try DNSConstants.validatedTLD(tld)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let install = dir.appendingPathComponent("install.sh")
        let uninstall = dir.appendingPathComponent("uninstall.sh")
        let reset = dir.appendingPathComponent("reset.sh")
        try installScript().write(to: install, atomically: true, encoding: .utf8)
        try uninstallScript().write(to: uninstall, atomically: true, encoding: .utf8)
        try resetScript().write(to: reset, atomically: true, encoding: .utf8)
        for s in [install, uninstall, reset] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: s.path)
        }
        return (install, uninstall, reset)
    }

    /// A fresh, unguessable, user-only staging dir for one run.
    public static func freshStagingDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kdwarm-dns-\(UUID().uuidString)")
    }

    public func runInstallWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).install.path)
    }
    public func runUninstallWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).uninstall.path)
    }
    public func runResetWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).reset.path)
    }

    /// Change the TLD from `old` to `new` via a single admin prompt (no-helper path). Stages the
    /// combined script in a fresh `0700` per-run dir (no predictable path to swap before root reads).
    public func runSetTLDWithAdminPrivileges(old: String, new: String) throws {
        // `old` and `new` are fresh untrusted inputs that reach root file paths + the dnsmasq heredoc
        // — validate both before staging/running anything as root.
        _ = try DNSConstants.validatedTLD(old)
        _ = try DNSConstants.validatedTLD(new)
        let dir = Self.freshStagingDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let script = dir.appendingPathComponent("set-tld.sh")
        try setTLDScript(old: old, new: new).write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        try runAsAdmin(script.path)
    }

    /// Run `bash <scriptPath>` via a GUI admin-authentication prompt. `scriptPath` lives in a
    /// freshly-created UUID dir under the user's `$TMPDIR` (no shell metacharacters by construction);
    /// it is additionally AppleScript-string-escaped and shell-quoted via `quoted form of`, so the
    /// root invocation is safe even if the path ever changed shape.
    private func runAsAdmin(_ scriptPath: String) throws {
        let asEscaped = scriptPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let osa = "do shell script \"/bin/bash \" & quoted form of \"\(asEscaped)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", osa]
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            throw NSError(domain: "KDWarm", code: Int(proc.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Admin authorization was cancelled or failed."])
        }
    }
}
