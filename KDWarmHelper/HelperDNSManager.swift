import Foundation

/// The privileged DNS operations the helper performs as root: write `/etc/resolver/test`, render
/// the dnsmasq config, and load/unload dnsmasq as a launchd daemon. Idempotent — re-enabling when
/// already enabled is a no-op; disabling cleans up fully.
///
/// Deferred-live: these run only inside the signed root helper (Phase 9). The identical operations
/// are scripted by the app's `SudoFallbackInstaller` for the no-helper path, both sourcing the
/// same `DNSConstants`, so the two paths cannot drift.
final class HelperDNSManager {
    func enableDNS(tld: String) -> (Bool, String?) {
        // Re-validate at the privileged boundary: the app-side check is a UX gate, not a trust
        // boundary, so a crafted `tld` (traversal / dnsmasq-config injection) must be refused here.
        guard let resolverPath = try? DNSConstants.resolverPathChecked(for: tld) else {
            return (false, "Invalid TLD.")
        }
        if let conflict = port53Owner(), conflict != DNSConstants.daemonLabel, conflict != "dnsmasq" {
            return (false, "Port 53 is already held by “\(conflict)”. Stop it (another DNS tool?) and retry.")
        }
        do {
            try writeRootFile(DNSConstants.dnsmasqConf(for: tld), to: DNSConstants.dnsmasqConfPath, mode: 0o644)
            try writeRootFile(DNSConstants.daemonPlist, to: DNSConstants.daemonPlistPath, mode: 0o644)
            try writeRootFile(DNSConstants.resolverContents, to: resolverPath, mode: 0o644)
            try bootstrapDaemon()
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    func disableDNS(tld: String) -> (Bool, String?) {
        guard let resolverPath = try? DNSConstants.resolverPathChecked(for: tld) else {
            return (false, "Invalid TLD.")
        }
        bootoutDaemon()
        try? FileManager.default.removeItem(atPath: resolverPath)
        try? FileManager.default.removeItem(atPath: DNSConstants.daemonPlistPath)
        return (true, nil)
    }

    /// Reconcile: tear everything down, then re-enable from a clean slate (recovers a stale resolver
    /// or a VPN-hijacked state).
    func resetDNS(tld: String) -> (Bool, String?) {
        _ = disableDNS(tld: tld)
        return enableDNS(tld: tld)
    }

    /// Change the dev TLD: remove the OLD resolver, then enable `new` (rewrites dnsmasq wildcard +
    /// writes the new resolver + restarts dnsmasq), then flush the DNS cache. Removing the old
    /// resolver is the critical step — leaving it orphaned would keep poisoning system DNS for a TLD
    /// that no longer resolves. No-ops cleanly when `old == new`.
    func setTLD(old: String, new: String) -> (Bool, String?) {
        // Both TLDs reach root file paths — validate each at the boundary.
        guard let oldResolver = try? DNSConstants.resolverPathChecked(for: old),
              (try? DNSConstants.validatedTLD(new)) != nil else {
            return (false, "Invalid TLD.")
        }
        if old != new {
            try? FileManager.default.removeItem(atPath: oldResolver)
        }
        let result = enableDNS(tld: new)
        _ = run("/usr/bin/dscacheutil", ["-flushcache"])
        return result
    }

    func status(tld: String) -> (resolverPresent: Bool, dnsmasqRunning: Bool, conflict: String?) {
        guard DNSConstants.isValidTLD(tld) else { return (false, false, nil) }
        let resolver = FileManager.default.fileExists(atPath: DNSConstants.resolverPath(for: tld))
        let running = launchctl(["print", "system/\(DNSConstants.daemonLabel)"]).status == 0
        let owner = port53Owner()
        // A conflict is only interesting when it is NOT our own dnsmasq.
        let conflict = (owner == nil || owner == "dnsmasq" || owner == DNSConstants.daemonLabel) ? nil : owner
        return (resolver, running, conflict)
    }

    // MARK: - Private

    private func bootstrapDaemon() throws {
        // Replace any prior instance so the config is always fresh.
        bootoutDaemon()
        let r = launchctl(["bootstrap", "system", DNSConstants.daemonPlistPath])
        guard r.status == 0 else {
            throw NSError(domain: "KDWarmHelper", code: Int(r.status),
                          userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap failed: \(r.output)"])
        }
    }

    private func bootoutDaemon() {
        _ = launchctl(["bootout", "system/\(DNSConstants.daemonLabel)"])
    }

    private func writeRootFile(_ contents: String, to path: String, mode: Int) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: path)
    }

    @discardableResult
    private func launchctl(_ args: [String]) -> (status: Int32, output: String) {
        run("/bin/launchctl", args)
    }

    /// Best-effort: which command holds `127.0.0.1:53` (UDP). nil if free.
    private func port53Owner() -> String? {
        let r = run("/usr/sbin/lsof", ["-nP", "-iUDP:\(DNSConstants.dnsPort)", "-F", "c"])
        for line in r.output.split(separator: "\n") where line.hasPrefix("c") {
            return String(line.dropFirst())
        }
        return nil
    }

    private func run(_ tool: String, _ args: [String]) -> (status: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tool)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do { try proc.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
