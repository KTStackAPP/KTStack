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

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = args
        proc.environment = ["PHP_INI_SCAN_DIR": paths.phpExtConfDir(version: version).path]
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        do { try proc.run() } catch { return .couldNotRun }
        let data = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        // php-fpm -t ghi cả "test is successful" ra stderr, nên chỉ xét exit code.
        if proc.terminationStatus != 0 {
            let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .invalid(msg)
        }
        return .valid
    }
}
