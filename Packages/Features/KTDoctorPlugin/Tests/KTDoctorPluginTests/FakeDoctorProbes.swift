import Foundation
import KTPlatformContracts
import KTStackCore

/// Fake test-only cho `DoctorProbing`: mỗi test chỉ chỉnh đúng closure/catalog mình quan tâm.
/// Catalog (bin names, default version) hardcode vì package không thấy BinaryStager/BundledPHP.
struct FakeDoctorProbes: DoctorProbing, @unchecked Sendable {
    static let binBinaries = ["nginx", "dnsmasq", "mkcert"]
    static let optionalBinaries = ["mailpit"]
    static let defaultVersion = "8.4"

    var helperStateFn: () async -> DoctorHelperState
    var fileExistsFn: (URL) -> Bool
    var readFileFn: (URL) -> String?
    var resolveHostFn: (String) -> [String]
    var isCATrustedFn: (URL) -> Bool
    var portStateFn: (Int) -> DoctorPortState
    var udp53ConflictFn: () -> DoctorDNSConflict?
    var verifySignatureFn: (URL) -> Bool
    var launchdJobStateFn: (String) -> DoctorLaunchdJobState?
    var stagedBinariesValue: [DoctorStagedBinary]
    var launchdJobsValue: [DoctorLaunchdJob]
    var installedPHPVersionsValue: [String]
    var defaultPHPVersionValue: String
    var phpPoolLabelFn: (String) -> String

    func helperState() async -> DoctorHelperState { await helperStateFn() }
    func fileExists(_ url: URL) -> Bool { fileExistsFn(url) }
    func readFile(_ url: URL) -> String? { readFileFn(url) }
    func resolveHost(_ host: String) -> [String] { resolveHostFn(host) }
    func isCATrusted(_ caCert: URL) -> Bool { isCATrustedFn(caCert) }
    func portState(_ port: Int) -> DoctorPortState { portStateFn(port) }
    func udp53Conflict() -> DoctorDNSConflict? { udp53ConflictFn() }
    func verifySignature(_ url: URL) -> Bool { verifySignatureFn(url) }
    func launchdJobState(_ label: String) -> DoctorLaunchdJobState? { launchdJobStateFn(label) }
    var stagedBinaries: [DoctorStagedBinary] { stagedBinariesValue }
    var launchdJobs: [DoctorLaunchdJob] { launchdJobsValue }
    var installedPHPVersions: [String] { installedPHPVersionsValue }
    var defaultPHPVersion: String { defaultPHPVersionValue }
    func phpPoolLabel(_ version: String) -> String { phpPoolLabelFn(version) }

    /// Máy khỏe hoàn toàn: 3 bin required + php-fpm default staged và present, mailpit optional vắng.
    static func healthy(paths: AppSupportPaths, tld: String) -> FakeDoctorProbes {
        let poolLabel: (String) -> String = { "com.ktstack.php-fpm.\($0)" }
        let staged =
            binBinaries.map { DoctorStagedBinary(name: $0, url: paths.binary($0), required: true) }
                + optionalBinaries.map { DoctorStagedBinary(name: $0, url: paths.binary($0), required: false) }
                + [DoctorStagedBinary(
                    name: "php-fpm \(defaultVersion)",
                    url: paths.phpFpmBinary(version: defaultVersion), required: false
                )]
        let jobs = [
            DoctorLaunchdJob(name: "Nginx", label: "com.ktstack.nginx"),
            DoctorLaunchdJob(name: "MySQL", label: "com.ktstack.mysql"),
            DoctorLaunchdJob(name: "PHP-FPM \(defaultVersion)", label: poolLabel(defaultVersion)),
        ]
        let present = Set(
            [paths.caRootCert.path, paths.certsDir.path]
                + binBinaries.map { paths.binary($0).path }
                + [
                    paths.phpFpmBinary(version: defaultVersion).path,
                    paths.phpFpmSocket(defaultVersion).path,
                ]
        )
        let resolverPath = DNSConstants.resolverPath(for: tld)
        return FakeDoctorProbes(
            helperStateFn: { DoctorHelperState(registration: .enabled, version: HelperIdentity.bundleVersion) },
            fileExistsFn: { present.contains($0.path) },
            readFileFn: { $0.path == resolverPath ? DNSConstants.resolverContents : nil },
            resolveHostFn: { $0 == "probe.\(tld)" ? ["127.0.0.1"] : [] },
            isCATrustedFn: { _ in true },
            portStateFn: { _ in .free },
            udp53ConflictFn: { nil },
            verifySignatureFn: { _ in true },
            launchdJobStateFn: { _ in DoctorLaunchdJobState(isRunning: true, lastExitCode: 0) },
            stagedBinariesValue: staged,
            launchdJobsValue: jobs,
            installedPHPVersionsValue: [defaultVersion],
            defaultPHPVersionValue: defaultVersion,
            phpPoolLabelFn: poolLabel
        )
    }
}
