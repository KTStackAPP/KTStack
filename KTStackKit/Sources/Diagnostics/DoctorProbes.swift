import Foundation
import KTPlatformContracts
import KTStackCore

/// Mọi lần chạm hệ thống của Doctor đi qua struct này, nên các check là logic thuần và test được.
/// Đường live dựng từ `DoctorProbeService`; `launchdSummary` vẫn là chuỗi vì check services/php
/// tự parse `LaunchdJobState`.
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
        let service = DoctorProbeService(paths: paths)
        let diagnostics = ServiceDiagnostics(paths: paths)
        return DoctorProbes(
            helperState: { await service.helperState() },
            fileExists: { service.fileExists($0) },
            readFile: { service.readFile($0) },
            resolveHost: { service.resolveHost($0) },
            isCATrusted: { service.isCATrusted($0) },
            portState: { service.portState($0) },
            udp53Conflict: { service.udp53Conflict() },
            verifySignature: { service.verifySignature($0) },
            launchdSummary: { diagnostics.launchdSummary($0) }
        )
    }
}
