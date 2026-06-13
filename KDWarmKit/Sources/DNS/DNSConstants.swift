import Foundation

/// Root-owned paths + config renderers for the `.test` DNS automation, shared by the privileged
/// helper (which performs the operations) and the `SudoFallbackInstaller` (which scripts the same
/// operations for the no-helper path). One source of truth so the two paths can't drift.
public enum DNSConstants {
    /// macOS per-TLD resolver file for `tld`. Its mere presence routes `*.<tld>` lookups to the
    /// nameserver below. The TLD is configurable (Phase 5) so the path is derived, not constant —
    /// the helper and the sudo fallback both call this so the two privileged paths can't drift.
    public static func resolverPath(for tld: String) -> String { "/etc/resolver/\(tld)" }

    // MARK: - Privileged-boundary validation
    //
    // The TLD flows into root file paths (`/etc/resolver/<tld>`) and into the root dnsmasq config
    // (`address=/.<tld>/…`, written via a heredoc that cannot be shell-quoted). The app validates a
    // TLD before persisting it, but that is a UX gate — not a trust boundary. The privileged paths
    // (helper + sudo fallback) re-validate here so a crafted value (path traversal, or a newline that
    // injects extra dnsmasq directives) can never reach a root operation.

    /// Thrown when a TLD fails privileged-boundary validation.
    public struct InvalidTLD: Error, CustomStringConvertible {
        public let value: String
        public init(_ value: String) { self.value = value }
        public var description: String { "Invalid TLD" }
    }

    /// Hostname-syntax check for a dev TLD: ASCII lowercase RFC-1123 labels only. Rejects empty,
    /// uppercase, non-ASCII, any whitespace/control char (incl. newlines), `/`, `..`, and
    /// leading/trailing dots. The explicit control-char/`/` guard is load-bearing: Swift's `^…$`
    /// anchors match *before* a trailing newline, so a regex alone would let `"test\n…"` slip through
    /// and inject dnsmasq directives.
    public static func isValidTLD(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 253, s == s.lowercased(),
              !s.hasPrefix("."), !s.hasSuffix(".") else { return false }
        let forbidden = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "/"))
        guard s.unicodeScalars.allSatisfy({ $0.isASCII && !forbidden.contains($0) }) else { return false }
        let labels = s.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        let label = #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"#
        return labels.allSatisfy { $0.range(of: label, options: .regularExpression) != nil }
    }

    /// Validate `tld` at a privileged boundary; return it unchanged iff valid, else throw.
    public static func validatedTLD(_ tld: String) throws -> String {
        guard isValidTLD(tld) else { throw InvalidTLD(tld) }
        return tld
    }

    /// `/etc/resolver/<tld>` with a defense-in-depth canonicalization guard: validates `tld`, then
    /// asserts the resolved path's parent is exactly `/etc/resolver`, so even a validator gap can't
    /// let the path escape into another root-owned directory.
    public static func resolverPathChecked(for tld: String) throws -> String {
        let path = resolverPath(for: try validatedTLD(tld))
        let parent = URL(fileURLWithPath: path).standardizedFileURL.deletingLastPathComponent().path
        guard parent == "/etc/resolver" else { throw InvalidTLD(tld) }
        return path
    }

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
