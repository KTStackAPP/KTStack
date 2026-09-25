import Foundation
import KTStackCore

// Chạy `php-fpm -t` trên pool conf đã render để chặn cấu hình hỏng trước khi restart.
public struct PHPFPMConfigCheck: Sendable {
    public enum Result: Sendable, Equatable {
        case valid
        case invalid(String)
        case couldNotRun
    }

    private let paths: AppSupportPaths

    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    public func run(version: String) -> Result {
        let binary = paths.phpFpmBinary(version: version)
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { return .couldNotRun }

        var args = ["-t", "-y", paths.phpFpmPool(version).path, "-p", paths.root.path]
        let ini = paths.phpIni(version: version)
        if FileManager.default.fileExists(atPath: ini.path) {
            args += ["-c", ini.path]
        }

        let request = ProcessRequest(
            executable: binary.path,
            arguments: args,
            environment: ["PHP_INI_SCAN_DIR": paths.phpExtConfDir(version: version).path],
            timeout: ToolTimeout.configTest
        )
        guard let res = try? ProcessRunner().run(request) else { return .couldNotRun }
        if res.interruption == .timedOut { return .invalid("php-fpm -t timed out") }
        // php-fpm -t ghi cả "test is successful" ra stderr, nên chỉ xét exit code.
        if res.status != 0 {
            return .invalid(res.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .valid
    }
}
