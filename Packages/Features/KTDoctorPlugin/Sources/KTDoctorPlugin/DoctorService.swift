import Foundation
import KTPlatformContracts
import KTPluginKit
import KTStackCore

/// Chạy toàn bộ self-check và gom thành một report. Read-only: không start/stop/ghi gì.
public struct DoctorService: Sendable {
    private let paths: AppSupportPaths
    private let tld: String
    private let probes: any DoctorProbing
    private let now: @Sendable () -> Date

    public init(
        paths: AppSupportPaths,
        tld: String,
        probes: any DoctorProbing,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.paths = paths
        self.tld = tld
        self.probes = probes
        self.now = now
    }

    /// providers append sau 7 core check theo thứ tự registry. providers không Sendable nên await
    /// tuần tự trên actor của caller (MainActor); phần core đồng bộ chạy trong Task.detached off main.
    public func run(
        environment: DoctorEnvironment? = nil,
        providers: [any DoctorCheckProviding] = []
    ) async -> DoctorReport {
        let env = environment ?? .current(tld: tld)
        let helperState = await probes.helperState()

        let paths = paths, tld = tld, probes = probes
        var checks = await Task.detached(priority: .userInitiated) {
            [
                DoctorChecks.helper(helperState),
                DoctorChecks.dns(tld: tld, probes: probes),
                DoctorChecks.tls(tld: tld, paths: paths, probes: probes),
                DoctorChecks.ports(probes: probes),
                DoctorChecks.binaries(probes: probes),
                DoctorChecks.services(probes: probes),
                DoctorChecks.php(paths: paths, probes: probes),
            ]
        }.value

        for provider in providers { checks += await provider.doctorChecks() }

        return DoctorReport(generatedAt: now(), environment: env, checks: checks)
    }
}
