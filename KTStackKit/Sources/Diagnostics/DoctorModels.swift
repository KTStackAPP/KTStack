import Foundation

public enum DoctorStatus: String, Sendable, Equatable, CaseIterable {
    case pass, warn, fail

    var severity: Int {
        switch self {
        case .pass: 0
        case .warn: 1
        case .fail: 2
        }
    }

    static func worst(_ statuses: [DoctorStatus]) -> DoctorStatus {
        statuses.max { $0.severity < $1.severity } ?? .pass
    }
}

/// Doctor chỉ đọc trạng thái; mỗi remedy trỏ về một action đã có sẵn trong app.
public enum DoctorRemedyAction: String, Sendable, Equatable {
    case openLoginItems, openServices, openSettings, openRuntimes
}

public struct DoctorCheck: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let status: DoctorStatus
    public let detail: String
    public let remedy: String?
    public let action: DoctorRemedyAction?

    public init(
        id: String,
        title: String,
        status: DoctorStatus,
        detail: String,
        remedy: String? = nil,
        action: DoctorRemedyAction? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
        self.remedy = remedy
        self.action = action
    }
}

public struct DoctorEnvironment: Sendable, Equatable {
    public let appVersion: String
    public let appBuild: String
    public let systemVersion: String
    public let architecture: String
    public let tld: String

    public init(appVersion: String, appBuild: String, systemVersion: String, architecture: String, tld: String) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.systemVersion = systemVersion
        self.architecture = architecture
        self.tld = tld
    }

    public static func current(tld: String, bundle: Bundle = .main) -> DoctorEnvironment {
        let info = bundle.infoDictionary
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return DoctorEnvironment(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info?["CFBundleVersion"] as? String ?? "unknown",
            systemVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            architecture: machineArchitecture(),
            tld: tld
        )
    }

    /// uname -m: phân biệt build arm64 chạy native với build x86_64 chạy qua Rosetta.
    static func machineArchitecture() -> String {
        var info = utsname()
        guard uname(&info) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &info.machine) { raw in
            String(bytes: raw.prefix { $0 != 0 }, encoding: .utf8) ?? "unknown"
        }
    }
}

/// Report chỉ chứa những gì KTStack tự sinh ra. Không kèm log tail: log PHP-FPM và nginx mang
/// DSN, mật khẩu DB và URI của user, mà report này được dán thẳng lên GitHub issue.
public struct DoctorReport: Sendable, Equatable {
    public let generatedAt: Date
    public let environment: DoctorEnvironment
    public let checks: [DoctorCheck]

    public init(generatedAt: Date, environment: DoctorEnvironment, checks: [DoctorCheck]) {
        self.generatedAt = generatedAt
        self.environment = environment
        self.checks = checks
    }

    public var status: DoctorStatus {
        DoctorStatus.worst(checks.map(\.status))
    }

    public var failures: [DoctorCheck] {
        checks.filter { $0.status != .pass }
    }
}
