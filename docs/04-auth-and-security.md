# 04. Authentication, Authorization & Security

[Previous: Data Models](03-data-models.md) · [Index](README.md) · [Next: Business Domains](05-business-domains.md)

---

## 1. Security Architecture & Privilege Model

Local development environments face a classic privilege challenge: binding system ports (`:80`, `:443`, `:53`) and managing system DNS `/etc/resolver/` typically require root permissions, but running an entire web server, database engine, and UI as root introduces unacceptable security risks.

KTStack resolves this by implementing a **strict least-privilege architecture**:

```mermaid
flowchart TD
    subgraph RootZone["Root Context (com.ktstack.helper)"]
        Helper["Privileged Helper Daemon\n(SMAppService Root)"]
        Dnsmasq["dnsmasq (Binds :53)"]
        Resolver["/etc/resolver/test"]
        Keychains["macOS System Keychain"]
    end

    subgraph UserZone["Unprivileged User Context (KTStack.app)"]
        App["KTStack Main Application\n(Developer ID Signed + Hardened Runtime)"]
        FrontNginx["Front Nginx (:80, :443)\n(Launched via launchd agent)"]
        PHPBackends["PHP-FPM & Site Backends"]
        Databases["Databases (MySQL, Postgres, SQLite)"]
    end

    App -->|"Mach-O XPC (NSXPCConnection)\nValidates Client Code Signature"| Helper
    Helper -->|"Spawns"| Dnsmasq
    Helper -->|"Writes"| Resolver
    Helper -->|"Installs CA (-p ssl -p basic)"| Keychains
    
    App -->|"User launchd"| FrontNginx
    App -->|"User launchd"| PHPBackends
    App -->|"User launchd"| Databases
```

### The Root Helper Contract:
The root helper (`KTStackHelper`) is restricted to strictly three actions:
1. Managing `/etc/resolver/<tld>` to point local domain queries to `127.0.0.1`.
2. Spawning and supervising `dnsmasq` bound to privileged port `53`.
3. Installing and trusting the generated Root CA in the System Keychain.

All other operations—reverse proxies, PHP-FPM pools, database engines, site file access, and user interaction—execute entirely within the unprivileged user's security context.

---

## 2. Privilege Separation via `SMAppService` & XPC

KTStack utilizes modern macOS 13+ `SMAppService.daemon(plistName: "com.ktstack.helper.plist")`, completely replacing deprecated `SMJobBless` workflows.

### 2.1 XPC Protocol Contract (`HelperProtocol.swift`)
```swift
@objc(KTStackHelperProtocol)
public protocol KTStackHelperProtocol {
    func installResolver(tld: String, withReply reply: @escaping (Bool, String?) -> Void)
    func removeResolver(tld: String, withReply reply: @escaping (Bool, String?) -> Void)
    func startDnsmasq(binaryPath: String, configPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    func stopDnsmasq(withReply reply: @escaping (Bool, String?) -> Void)
    func installRootCA(certPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    func removeRootCA(certPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    func getVersion(withReply reply: @escaping (String) -> Void)
}
```

### 2.2 Client Validation & Code Signature Verification
To prevent malicious local processes from exploiting the XPC listener, `KTStackHelper` validates the caller's identity on every connection:
1. Retrieves client process audit token via `xpc_connection_get_audit_token`.
2. Evaluates code signature using `SecCodeCopyGuestWithAttributes`.
3. Verifies that the client's **Team ID** matches the official KTStack Apple Developer Team ID (`SecRequirementCreateWithString`).
4. Non-matching or untrusted callers are immediately rejected and logged.

---

## 3. macOS Root CA Trust & Verification Pipeline

KTStack mints internal TLS certificates via an embedded `mkcert` engine. To ensure modern browsers (Safari, Chrome) trust local sites without security warnings, the Root CA must be properly configured.

### 3.0 Name-Constrained Root CA
When `KTStack.restrictLocalCA` is on (the default), `RestrictedRootCA` generates the root CA with `/usr/bin/openssl` instead of letting mkcert create it. The CA carries a critical `nameConstraints` extension that permits only the safe dev TLDs (`test`, `home.arpa`, `internal`), the configured TLD, and the loopback ranges `127.0.0.0/8` and `::1`. It also has `pathlen:0`. The subject organization stays `mkcert development CA`, so the helper's `RootCAConstraint` check accepts it without a helper change. mkcert keeps minting leaf certificates from this CA as before. A sidecar `ktstack-ca-constraints.json` records the CA's SHA-256 fingerprint and permitted TLDs, and any CA without a matching sidecar counts as unrestricted. Regeneration stages the new CA first, then untrusts the old one, moves the old files to `ca/retired/<timestamp>/`, and trusts the new one. The site certificates are then re-issued through `CertRenewalPolicy`, which re-mints any leaf not issued by the current CA.

### 3.1 Policy Configuration Flags
When the helper installs the certificate into `/Library/Keychains/System.keychain`, it invokes:
```bash
security add-trusted-cert -d -r trustRoot -p ssl -p basic -k /Library/Keychains/System.keychain /path/to/rootCA.pem
```
**Critical Security Invariant**: The `-p ssl -p basic` flags are mandatory. Omitting them creates an ambiguous wildcard trust record that fails modern macOS strict TLS evaluation. Specifying `ssl` and `basic` binds trust explicitly to `sslServer` and `basicX509` policy OIDs.

### 3.2 Native Verification vs. CLI False Positives
Calling `security find-certificate` merely verifies the file exists in a keychain; it does **not** prove trust. KTStack evaluates trust using native `Security.framework` APIs:

```swift
public func verifyCertificateTrust(cert: SecCertificate) -> Bool {
    var trust: SecTrust?
    let policy = SecPolicyCreateSSL(true, nil)
    guard SecTrustCreateWithCertificates(cert, policy, &trust) == errSecSuccess,
          let trust else { return false }
    
    var error: CFError?
    return SecTrustEvaluateWithError(trust, &error)
}
```

---

## 4. Hardened Runtime & Code Signing Model

KTStack is distributed outside the Mac App Store as an open-source Developer-ID signed application.

### 4.1 Entitlements (`entitlements/`)
Every Mach-O is signed with Hardened Runtime. Entitlements are kept minimal and per binary:

| File | Signed onto | Keys |
|------|-------------|------|
| `entitlements/app.entitlements` | `KTStack.app`, `KTStackDatabaseLauncher`, and bundled non-JIT binaries (nginx, dnsmasq, mkcert, database engines) | `com.apple.security.app-sandbox = false` |
| `entitlements/helper.entitlements` | `KTStackHelper`, `ktstack-resolve`, `kt` | `com.apple.security.app-sandbox = false` |
| `entitlements/jit-runtime.entitlements` | JIT runtimes: `php`, `php-fpm`, `node` (and `java`/`ruby` if bundled) | `com.apple.security.cs.allow-jit = true` |

There is no `allow-unsigned-executable-memory`, `disable-library-validation` or network-client/server entitlement: those only matter inside the App Sandbox or for unsigned code, and every bundled PHP extension is signed with the same Developer ID (`scripts/release/sign-all-binaries.sh`, `sign-extensions.sh`).

### 4.2 Sandboxing Rationale
KTStack is deliberately **not sandboxed** (`com.apple.security.app-sandbox` is explicitly `false`). Sandboxing prohibits developer tools from accessing arbitrary project directories in `~/Sites` or `~/Projects`, interacting with `/etc/resolver/`, and supervising user launchd background jobs. Gatekeeper security is ensured via Apple Notarization and Hardened Runtime enforcement.

---

[Previous: Data Models](03-data-models.md) · [Index](README.md) · [Next: Business Domains](05-business-domains.md)
