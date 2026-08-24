import Foundation
import KTPluginKit

// worst/severity trên DoctorStatus của KTPluginKit: cần cho tổng hợp status, KTPluginKit không mang.
extension DoctorStatus {
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
