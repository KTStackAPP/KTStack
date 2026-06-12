import Foundation

/// Root-owned paths + config renderers for the `.test` DNS automation, shared by the privileged
/// helper (which performs the operations) and the `SudoFallbackInstaller` (which scripts the same
/// operations for the no-helper path). One source of truth so the two paths can't drift.
public enum DNSConstants {
    /// macOS per-TLD resolver file for `tld`. Its mere presence routes `*.<tld>` lookups to the
    /// nameserver below. The TLD is configurable (Phase 5) so the path is derived, not constant —
    /// the helper and the sudo fallback both call this so the two privileged paths can't drift.
    public static func resolverPath(for tld: String) -> String { "/etc/resolver/\(tld)" }

    /// Root-owned support dir holding the dnsmasq binary copy + its config (outside the user's
    /// writable app-support, since the daemon runs as root).
    public static let supportDir = "/Library/Application Support/KDWarm"
    public static var dnsmasqBinaryPath: String { "\(supportDir)/bin/dnsmasq" }
    public static var dnsmasqConfPath: String { "\(supportDir)/dnsmasq.conf" }
    public static var dnsmasqLogPath: String { "\(supportDir)/dnsmasq.log" }

    /// launchd daemon for dnsmasq (persists across app quit — consistent with Phase 6's model).
    public static let daemonLabel = "com.kdwarm.dnsmasq"
    public static var daemonPlistPath: String { "/Library/LaunchDaemons/\(daemonLabel).plist" }

    public static let dnsPort = 53

    /// `/etc/resolver/<tld>` body — route lookups for that TLD to the local dnsmasq. TLD-independent
    /// (the routing is keyed by the resolver file's name, not its contents).
    public static var resolverContents: String {
        "nameserver 127.0.0.1\nport \(dnsPort)\n"
    }

    /// Minimal dnsmasq config: answer ONLY `*.<tld>` with 127.0.0.1, bound to loopback, no upstream.
    public static func dnsmasqConf(for tld: String) -> String {
        """
        port=\(dnsPort)
        listen-address=127.0.0.1
        bind-interfaces
        no-resolv
        no-hosts
        address=/.\(tld)/127.0.0.1
        """
    }

    /// launchd daemon plist running the bundled dnsmasq in the foreground (`-k`) under launchd.
    public static var daemonPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(dnsmasqBinaryPath)</string>
                <string>-k</string>
                <string>--conf-file=\(dnsmasqConfPath)</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
            <key>StandardErrorPath</key><string>\(dnsmasqLogPath)</string>
            <key>StandardOutPath</key><string>\(dnsmasqLogPath)</string>
        </dict>
        </plist>
        """
    }
}
