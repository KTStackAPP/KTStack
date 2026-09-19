# 07. API & Data Flow Specifications

[Previous: Integration & Background](06-integration-and-background.md) · [Index](README.md) · [Next: Runtime & Deployment](08-runtime-and-deployment.md)

---

## 1. System Communication Tiers

KTStack coordinates communication across three distinct layers:
1. **Inter-Process Communication (IPC)**: Mach-O XPC between the unprivileged app and the privileged root helper.
2. **In-Process Capability Contracts**: Swift protocols in `KTPlatformContracts` decoupling feature plugins from platform implementations.
3. **Network Data Flow**: HTTP/TLS reverse proxy routing, FastCGI protocol forwarding, and socket stream ingestion.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        In-Process Swift Tier                           │
│   App Host  ──(PluginLifecycle)──►  Feature Plugins (DB, Logs, Mail)   │
│   App Host  ◄──(KTPlatformContracts)──  SiteProviding, ServiceProviding│
├────────────────────────────────────────────────────────────────────────┤
│                       Inter-Process (IPC) Tier                         │
│   KTStack.app  ──(Mach-O XPC / HelperProtocol)──►  com.ktstack.helper │
├────────────────────────────────────────────────────────────────────────┤
│                       Network & Wire Data Flow                         │
│   Browser  ──(HTTPS/TLS :443)──►  Front Nginx                          │
│   Front Nginx  ──(HTTP Loopback)──►  Backend Nginx                     │
│   Backend Nginx  ──(FastCGI)──►  PHP-FPM Pool                          │
│   Symfony/Laravel  ──(TCP :9912)──►  KTDumpsPlugin Socket              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Privileged Helper XPC Contract (`HelperProtocol.swift`)

The privileged helper exposes an `@objc` protocol accessible over Mach-O XPC via `NSXPCConnection`:

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

### XPC Connection Lifecycle:
```mermaid
sequenceDiagram
    autonumber
    participant App as KTStack Client
    participant Conn as NSXPCConnection
    participant Helper as Helper XPC Listener

    App->>Conn: init(machServiceName: "com.ktstack.helper")
    Conn->>Helper: Establish Mach Channel
    Helper->>Helper: Verify Audit Token & Code Signature (Team ID)
    alt Validation Succeeded
        Helper-->>Conn: Accept Connection
        App->>Conn: remoteObjectProxy.installRootCA(path)
        Helper->>Helper: Execute security add-trusted-cert -p ssl -p basic
        Helper-->>App: Reply(success: true, error: nil)
    else Validation Failed
        Helper-->>Conn: Invalidate Connection (Untrusted Caller)
    end
```

---

## 3. Platform Capability Protocols (`KTPlatformContracts`)

To preserve modular isolation, feature packages never import `KTStackKit` or concrete services directly. They depend exclusively on capability protocols:

### 3.1 `SiteProviding` Contract
```swift
public protocol SiteProviding: Sendable {
    func getAllSites() async -> [Site]
    func getSite(by id: UUID) async -> Site?
    func observeSiteChanges() -> AsyncStream<[Site]>
}
```
*Used by*: `KTLogsPlugin` (populating site log pickers), `KTTunnelPlugin` (selecting sites to tunnel), `KTDoctorPlugin` (validating site configurations).

### 3.2 `ServiceProviding` Contract
```swift
public protocol ServiceProviding: Sendable {
    func getStatus(for service: ServiceKind) async -> ServiceStatus
    func restartService(_ service: ServiceKind) async throws
    func observeServiceStatuses() -> AsyncStream<[ServiceKind: ServiceStatus]>
}
```
*Used by*: `KTDoctorPlugin` (port probe verification), MenuBar status monitors.

---

## 4. End-to-End HTTP Request Data Flow

The following diagram tracks an incoming developer request from initial browser dispatch to backend execution:

```mermaid
flowchart TD
    Client["Browser: https://my-app.test/users"] -->|"1. DNS query my-app.test"| DNS["dnsmasq (127.0.0.1:53)"]
    DNS -->|"2. Returns 127.0.0.1"| Client
    Client -->|"3. HTTPS GET :443 (TLS SNI: my-app.test)"| FrontNginx["Front Nginx Gateway"]
    
    FrontNginx -->|"4. Match server_name -> proxy_pass 127.0.0.1:4012"| BackendNginx["Backend Nginx (Loopback :4012)"]
    
    BackendNginx -->|"5. FastCGI unix socket or TCP :9083\nInjected: SCRIPT_FILENAME, HTTPS=on"| PHPFPM["PHP-FPM Pool (PHP 8.3)"]
    
    PHPFPM -->|"6. FastCGI Response Stream"| BackendNginx
    BackendNginx -->|"7. HTTP Response"| FrontNginx
    FrontNginx -->|"8. TLS HTTP/2 Stream"| Client
```

### Data Flow Invariants:
1. **Loopback Port Isolation**: Each PHP site backend operates on an isolated port in the `4000-4999` range. Cross-site traffic leakage is structurally impossible.
2. **Environment Variable Injection**: Custom environment variables defined in `sites.json` are passed dynamically via FastCGI parameters (`fastcgi_param KEY "VALUE"`), ensuring PHP processes receive project-specific configuration without polluting system-wide environment variables.

---

[Previous: Integration & Background](06-integration-and-background.md) · [Index](README.md) · [Next: Runtime & Deployment](08-runtime-and-deployment.md)
