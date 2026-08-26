import Foundation
import KTPlatformContracts
import KTStackCore
#if canImport(ServiceManagement)
    import ServiceManagement
#endif

/// Platform conform của `DoctorProbing`: mọi lần chạm hệ thống của Doctor đi qua đây. Wrap
/// ServiceDiagnostics/PortPreflight/Port53ConflictDetector (struct stateless) nên @unchecked Sendable.
public final class DoctorProbeService: DoctorProbing, @unchecked Sendable {
    private let paths: AppSupportPaths
    private let diagnostics: ServiceDiagnostics
    private let preflight = PortPreflight()
    private let port53 = Port53ConflictDetector()

    public init(paths: AppSupportPaths) {
        self.paths = paths
        diagnostics = ServiceDiagnostics(paths: paths)
    }

    public func helperState() async -> DoctorHelperState {
        await Self.liveHelperState()
    }

    public func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func readFile(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    public func resolveHost(_ host: String) -> [String] {
        Self.resolveIPv4(host)
    }

    public func isCATrusted(_ caCert: URL) -> Bool {
        CATrustService.isTrustedInSystemKeychain(caCert: caCert)
    }

    public func portState(_ port: Int) -> DoctorPortState {
        switch preflight.check(port: port) {
        case .available: .free
        case let .inUse(process, message): .inUse(owner: process, message: message)
        case let .blocked(message): .unavailable(message: message)
        }
    }

    public func udp53Conflict() -> DoctorDNSConflict? {
        port53.check().map { DoctorDNSConflict(process: $0.process, message: $0.message) }
    }

    public func verifySignature(_ url: URL) -> Bool {
        BinaryStager.verifySignature(at: url)
    }

    public func launchdJobState(_ label: String) -> DoctorLaunchdJobState? {
        LaunchdJobState(summary: diagnostics.launchdSummary(label))
            .map { DoctorLaunchdJobState(isRunning: $0.isRunning, lastExitCode: $0.lastExitCode) }
    }

    public var stagedBinaries: [DoctorStagedBinary] {
        var staged = BinaryStager.binBinaries.map {
            DoctorStagedBinary(name: $0, url: paths.binary($0), required: true)
        }
        staged += BinaryStager.optionalBinaryNames.map {
            DoctorStagedBinary(name: $0, url: paths.binary($0), required: false)
        }
        staged += installedPHPVersions.map {
            DoctorStagedBinary(name: "php-fpm \($0)", url: paths.phpFpmBinary(version: $0), required: false)
        }
        return staged
    }

    public var launchdJobs: [DoctorLaunchdJob] {
        var jobs = ServiceKind.allCases
            .filter { $0 != .phpFpm && $0 != .dnsmasq }
            .map { DoctorLaunchdJob(name: $0.displayName, label: $0.launchdLabel) }
        jobs += installedPHPVersions.map {
            DoctorLaunchdJob(name: "PHP-FPM \($0)", label: phpPoolLabel($0))
        }
        return jobs
    }

    public var installedPHPVersions: [String] {
        BundledPHP.plannedVersions.filter { fileExists(paths.phpFpmBinary(version: $0)) }
    }

    public var defaultPHPVersion: String {
        BundledPHP.defaultVersion
    }

    public func phpPoolLabel(_ version: String) -> String {
        "\(ServiceKind.phpFpm.launchdLabel).\(version)"
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

/// Các trường `launchctl print` mà `ServiceDiagnostics.launchdSummary` giữ lại. `nil` = job chưa nạp.
/// Format chuỗi là của platform: plugin nhận `DoctorLaunchdJobState` structured, không parse.
struct LaunchdJobState {
    let isRunning: Bool
    let lastExitCode: Int?

    init?(summary: String) {
        guard !summary.hasPrefix("job not loaded") else { return nil }
        var running = false
        var exitCode: Int?
        for raw in summary.split(separator: ";") {
            let field = raw.trimmingCharacters(in: .whitespaces)
            // "not running" cũng chứa "running", nên so khớp nguyên giá trị.
            if field.hasPrefix("state =") {
                running = field.dropFirst("state =".count).trimmingCharacters(in: .whitespaces) == "running"
            }
            if field.hasPrefix("last exit code =") {
                exitCode = Int(field.dropFirst("last exit code =".count).trimmingCharacters(in: .whitespaces))
            }
        }
        isRunning = running
        lastExitCode = exitCode
    }

    /// launchd giữ mã thoát của lần chạy trước, nên job đang chạy không phải là start hỏng.
    var failedStart: Bool {
        !isRunning && (lastExitCode ?? 0) != 0
    }
}
