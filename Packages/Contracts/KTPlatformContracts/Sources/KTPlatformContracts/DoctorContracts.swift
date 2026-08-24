import Foundation

// Trạng thái helper privileged mà Doctor cần; platform (DoctorProbeService) resolve qua XPC.
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

public struct DoctorStagedBinary: Sendable, Equatable {
    public let name: String
    public let url: URL
    public let required: Bool

    public init(name: String, url: URL, required: Bool) {
        self.name = name
        self.url = url
        self.required = required
    }
}

public struct DoctorLaunchdJob: Sendable, Equatable {
    public let name: String
    public let label: String

    public init(name: String, label: String) {
        self.name = name
        self.label = label
    }
}

// Trường launchctl mà platform giữ lại. nil từ probe = job chưa nạp. launchd giữ exit code lần
// trước, nên plugin suy failedStart = !isRunning && exit != 0 (job đang chạy không phải start hỏng).
public struct DoctorLaunchdJobState: Sendable, Equatable {
    public let isRunning: Bool
    public let lastExitCode: Int?

    public init(isRunning: Bool, lastExitCode: Int?) {
        self.isRunning = isRunning
        self.lastExitCode = lastExitCode
    }

    public var failedStart: Bool {
        !isRunning && (lastExitCode ?? 0) != 0
    }
}

// Mọi lần chạm hệ thống của Doctor đi qua đây; conform trong KTStackKit. Read-only: không start/stop/ghi.
// Plugin không biết BinaryStager/ServiceKind/BundledPHP: catalog trả sẵn từ platform.
public protocol DoctorProbing: Sendable {
    func helperState() async -> DoctorHelperState
    func fileExists(_ url: URL) -> Bool
    func readFile(_ url: URL) -> String?
    func resolveHost(_ host: String) -> [String]
    func isCATrusted(_ caCert: URL) -> Bool
    func portState(_ port: Int) -> DoctorPortState
    func udp53Conflict() -> DoctorDNSConflict?
    func verifySignature(_ url: URL) -> Bool
    func launchdJobState(_ label: String) -> DoctorLaunchdJobState?
    // bin (required) + optional + php-fpm mỗi version đã cài, đúng thứ tự binaries check dựng.
    var stagedBinaries: [DoctorStagedBinary] { get }
    // user-domain jobs (bỏ phpFpm/dnsmasq) + PHP-FPM pool mỗi version cài.
    var launchdJobs: [DoctorLaunchdJob] { get }
    var installedPHPVersions: [String] { get }
    var defaultPHPVersion: String { get }
    func phpPoolLabel(_ version: String) -> String
}
