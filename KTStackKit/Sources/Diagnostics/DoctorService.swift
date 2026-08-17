import Foundation

/// Chạy toàn bộ self-check và gom thành một report. Read-only: không start/stop/ghi gì.
public struct DoctorService: Sendable {
    private let paths: AppSupportPaths
    private let tld: String
    private let probes: DoctorProbes
    private let now: @Sendable () -> Date

    public init(
        paths: AppSupportPaths,
        tld: String,
        probes: DoctorProbes? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.paths = paths
        self.tld = tld
        self.probes = probes ?? .live(paths: paths)
        self.now = now
    }

    public func run(environment: DoctorEnvironment? = nil) async -> DoctorReport {
        let env = environment ?? .current(tld: tld)
        // Chỉ helper cần await; phần còn lại là I/O đồng bộ, cả hàm chạy off main actor.
        let helperState = await probes.helperState()

        return DoctorReport(
            generatedAt: now(),
            environment: env,
            checks: [
                DoctorChecks.helper(helperState),
                DoctorChecks.dns(tld: tld, probes: probes),
                DoctorChecks.tls(tld: tld, paths: paths, probes: probes),
                DoctorChecks.ports(probes: probes),
                DoctorChecks.binaries(paths: paths, probes: probes),
                DoctorChecks.services(paths: paths, probes: probes),
                DoctorChecks.php(paths: paths, probes: probes),
            ]
        )
    }
}
