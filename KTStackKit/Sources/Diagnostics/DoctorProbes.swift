import Foundation
#if canImport(ServiceManagement)
    import ServiceManagement
#endif

public enum DoctorPortState: Sendable, Equatable {
    case free
    case inUse(owner: String?, message: String)
    case unavailable(message: String)
}

public struct DoctorDNSConflict: Sendable, Equatable {
    public let process: String
    public let message: String

    public init(process: String, message: String) {
        self.process = process
        self.message = message
    }
}

public struct DoctorHelperState: Sendable, Equatable {
    public enum Registration: String, Sendable {
        case notApplicable // build không có signing identity, DNS đi đường sudo fallback
        case notRegistered
        case requiresApproval
        case enabled
    }

    public let registration: Registration
    public let version: String?
    public let error: String?

    public init(registration: Registration, version: String? = nil, error: String? = nil) {
        self.registration = registration
        self.version = version
        self.error = error
    }
}

/// Mọi lần chạm hệ thống của Doctor đi qua struct này, nên các check là logic thuần và test được.
public struct DoctorProbes: Sendable {
    public var helperState: @Sendable () async -> DoctorHelperState
    public var fileExists: @Sendable (URL) -> Bool
    public var readFile: @Sendable (URL) -> String?
    public var resolveHost: @Sendable (String) -> [String]
    public var isCATrusted: @Sendable (URL) -> Bool
    public var portState: @Sendable (Int) -> DoctorPortState
    public var udp53Conflict: @Sendable () -> DoctorDNSConflict?
    public var verifySignature: @Sendable (URL) -> Bool
    public var launchdSummary: @Sendable (String) -> String

    public init(
        helperState: @escaping @Sendable () async -> DoctorHelperState,
        fileExists: @escaping @Sendable (URL) -> Bool,
        readFile: @escaping @Sendable (URL) -> String?,
        resolveHost: @escaping @Sendable (String) -> [String],
        isCATrusted: @escaping @Sendable (URL) -> Bool,
        portState: @escaping @Sendable (Int) -> DoctorPortState,
        udp53Conflict: @escaping @Sendable () -> DoctorDNSConflict?,
        verifySignature: @escaping @Sendable (URL) -> Bool,
        launchdSummary: @escaping @Sendable (String) -> String
    ) {
        self.helperState = helperState
        self.fileExists = fileExists
        self.readFile = readFile
        self.resolveHost = resolveHost
        self.isCATrusted = isCATrusted
        self.portState = portState
        self.udp53Conflict = udp53Conflict
        self.verifySignature = verifySignature
        self.launchdSummary = launchdSummary
    }

    public static func live(paths: AppSupportPaths) -> DoctorProbes {
        let diagnostics = ServiceDiagnostics(paths: paths)
        let preflight = PortPreflight()
        let port53 = Port53ConflictDetector()
        return DoctorProbes(
            helperState: { await liveHelperState() },
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            readFile: { try? String(contentsOf: $0, encoding: .utf8) },
            resolveHost: { resolveIPv4($0) },
            isCATrusted: { CATrustService.isTrustedInSystemKeychain(caCert: $0) },
            portState: {
                switch preflight.check(port: $0) {
                case .available: .free
                case let .inUse(process, message): .inUse(owner: process, message: message)
                case let .blocked(message): .unavailable(message: message)
                }
            },
            udp53Conflict: {
                port53.check().map { DoctorDNSConflict(process: $0.process, message: $0.message) }
            },
            verifySignature: { BinaryStager.verifySignature(at: $0) },
            launchdSummary: { diagnostics.launchdSummary($0) }
        )
    }

    static func resolveIPv4(_ host: String) -> [String] {
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM, ai_protocol: 0,
            ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let head = result else { return [] }
        defer { freeaddrinfo(head) }

        var addresses: [String] = []
        var node: UnsafeMutablePointer<addrinfo>? = head
        while let current = node {
            if let sa = current.pointee.ai_addr {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    sa, current.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST
                ) == 0 {
                    addresses.append(String(cString: buffer))
                }
            }
            node = current.pointee.ai_next
        }
        return addresses
    }

    /// Ping qua XPC có thể không bao giờ trả lời (helper chưa được duyệt, kết nối chết), nên
    /// có timeout và chốt resume-một-lần: error handler và reply đều có thể bắn.
    static func liveHelperState(timeout: TimeInterval = 3) async -> DoctorHelperState {
        guard HelperIdentity.hasSigningIdentity else {
            return DoctorHelperState(registration: .notApplicable)
        }
        let registration = daemonRegistration()
        guard registration == .enabled else { return DoctorHelperState(registration: registration) }

        let helper = HelperConnection()
        let once = ResumeGuard()
        var timeoutTask: Task<Void, Never>?

        let state = await withCheckedContinuation { continuation in
            let finish: @Sendable (DoctorHelperState) -> Void = { state in
                if once.claim() { continuation.resume(returning: state) }
            }
            let fail: @Sendable (String) -> Void = { message in
                finish(DoctorHelperState(registration: .enabled, error: message))
            }

            guard let proxy = helper.remoteProxy({ fail($0.localizedDescription) }) else {
                fail("Could not open an XPC connection to the helper.")
                return
            }
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                fail("Helper did not answer within \(Int(timeout))s.")
            }
            proxy.ping { _ in
                proxy.helperVersion { version in
                    finish(DoctorHelperState(registration: .enabled, version: version))
                }
            }
        }

        timeoutTask?.cancel()
        helper.invalidate()
        return state
    }

    static func daemonRegistration() -> DoctorHelperState.Registration {
        #if canImport(ServiceManagement)
            if #available(macOS 13, *) {
                switch SMAppService.daemon(plistName: HelperIdentity.daemonPlistName).status {
                case .enabled: return .enabled
                case .requiresApproval: return .requiresApproval
                default: return .notRegistered
                }
            }
        #endif
        return .notRegistered
    }
}

private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
