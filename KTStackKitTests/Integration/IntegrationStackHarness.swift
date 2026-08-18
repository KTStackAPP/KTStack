import Darwin
import Foundation
import KTStackCore
import XCTest
@testable import KTStackKit

/// Boots real nginx (front + per-site backend) and php-fpm from the production config writers
/// against a disposable root under /tmp, on probed high loopback ports. No root, no launchd,
/// never touches the real ~/Library/Application Support/KTStack/.
final class IntegrationStackHarness {
    let paths: AppSupportPaths
    let httpPort: Int
    let httpsPort: Int

    private var running: [Process] = []

    enum HarnessError: LocalizedError {
        case missingBinary(String, searched: URL)
        case portProbeFailed
        case commandFailed(String, output: String)
        case portNeverBound(Int, errorLogTail: String)
        case fileNeverAppeared(URL, logTail: String)
        case unmappedListenDirective(URL)

        var errorDescription: String? {
            switch self {
            case let .missingBinary(name, searched):
                """
                Missing bundled binary “\(name)” in \(searched.path). Bundled binaries are gitignored \
                build artifacts; build/stage them first (scripts/build-*-relocatable.sh, see README \
                “Build from source”), or point KTSTACK_BIN_DIR at a directory that has them.
                """
            case .portProbeFailed:
                "Could not bind-probe a free loopback port."
            case let .commandFailed(what, output):
                "\(what) failed: \(output)"
            case let .portNeverBound(port, tail):
                "127.0.0.1:\(port) never accepted connections. nginx error log tail:\n\(tail)"
            case let .fileNeverAppeared(url, tail):
                "\(url.path) never appeared. Log tail:\n\(tail)"
            case let .unmappedListenDirective(file):
                """
                \(file.lastPathComponent) still has a production listen directive after the port \
                remap; the writer output changed. Update remapFrontListenPorts so the harness never \
                binds the real :80/:443.
                """
            }
        }
    }

    static func requireEnabled() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KTSTACK_INTEGRATION"] == "1",
            "integration tests run only with KTSTACK_INTEGRATION=1 (scripts/integration-test.sh)"
        )
    }

    /// Root stays short (/tmp, 8-char suffix) so php-fpm unix socket paths fit the 104-byte limit.
    init() throws {
        let suffix = UUID().uuidString.prefix(8).lowercased()
        let root = URL(fileURLWithPath: "/tmp/ktstack-it-\(suffix)", isDirectory: true)
        paths = AppSupportPaths(root: root)
        do {
            try paths.ensureDirectoryTree()
            httpPort = try Self.probeFreePort()
            httpsPort = try Self.probeFreePort()
            try stageBinaries()
        } catch {
            // A failed init never reaches teardown(), so clean the temp root here.
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    func teardown() {
        for proc in running.reversed() where proc.isRunning {
            proc.terminate()
        }
        let deadline = Date().addingTimeInterval(3)
        for proc in running.reversed() {
            while proc.isRunning, Date() < deadline {
                usleep(50000)
            }
            if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
        }
        running.removeAll()
        killStrayPidsFromPidFiles()
        try? FileManager.default.removeItem(at: paths.root)
    }

    /// Backup teardown: kill by pid file in the temp root, never by binary name
    /// (all site backends share one nginx binary).
    private func killStrayPidsFromPidFiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: paths.run, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "pid" {
            guard let text = try? String(contentsOf: file, encoding: .utf8),
                  let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  pid > 0
            else { continue }
            if kill(pid, 0) == 0 { kill(pid, SIGTERM) }
        }
    }

    static func repoBinDir() -> URL {
        if let env = ProcessInfo.processInfo.environment["KTSTACK_BIN_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // #filePath = <repo>/KTStackKitTests/Integration/IntegrationStackHarness.swift
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("KTStack/Resources/bin", isDirectory: true)
    }

    private func stageBinaries() throws {
        let source = Self.repoBinDir()
        let fm = FileManager.default
        for name in ["nginx", "mkcert"] {
            let src = source.appendingPathComponent(name)
            guard fm.isExecutableFile(atPath: src.path) else {
                throw HarnessError.missingBinary(name, searched: source)
            }
            try fm.createSymbolicLink(at: paths.binary(name), withDestinationURL: src)
        }
    }

    func mintCert(domain: String) throws {
        let runner = MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir)
        try CertMinter(paths: paths, runner: runner).mint(name: domain, domain: domain)
    }

    func makeDocroot(_ name: String, files: [String: String]) throws -> URL {
        let dir = paths.sites.appendingPathComponent(name, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for (relative, content) in files {
            let file = dir.appendingPathComponent(relative)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        return dir
    }

    func generateConfigs(sites: [Site]) throws {
        try SiteConfigGenerator(paths: paths).generate(sites: sites)
        try remapFrontListenPorts()
    }

    /// The front writers pin :80/:443 (production contract). The harness must not own those
    /// ports, so only the listen directives are remapped onto the probed loopback ports;
    /// everything else in the generated files stays byte-for-byte production output.
    private func remapFrontListenPorts() throws {
        let fm = FileManager.default
        var files = [paths.nginxConf]
        if let vhosts = try? fm.contentsOfDirectory(at: paths.sitesEnabled, includingPropertiesForKeys: nil) {
            files += vhosts.filter { $0.pathExtension == "conf" }
        }
        for file in files {
            var text = try String(contentsOf: file, encoding: .utf8)
            text = text.replacingOccurrences(
                of: "listen \(NginxConfigWriter.listenAddress):80",
                with: "listen 127.0.0.1:\(httpPort)"
            )
            text = text.replacingOccurrences(
                of: "listen \(NginxConfigWriter.listenAddress):443 ssl",
                with: "listen 127.0.0.1:\(httpsPort) ssl"
            )
            // Fail closed on writer drift: a surviving production listen line would bind :80/:443.
            guard !text.contains("listen \(NginxConfigWriter.listenAddress):") else {
                throw HarnessError.unmappedListenDirective(file)
            }
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    @discardableResult
    static func run(
        _ executable: URL,
        _ arguments: [String],
        environment: [String: String]? = nil
    ) throws -> (status: Int32, output: String) {
        let proc = Process()
        proc.executableURL = executable
        proc.arguments = arguments
        if let environment { proc.environment = environment }
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    @discardableResult
    func launch(
        _ executable: URL,
        _ arguments: [String],
        environment: [String: String]? = nil,
        log: URL
    ) throws -> Process {
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        let proc = Process()
        proc.executableURL = executable
        proc.arguments = arguments
        if let environment { proc.environment = environment }
        proc.standardOutput = handle
        proc.standardError = handle
        try proc.run()
        running.append(proc)
        return proc
    }

    @discardableResult
    func nginxT(conf: URL) throws -> String {
        let (status, output) = try Self.run(
            paths.nginxBinary,
            ["-p", paths.root.path, "-c", conf.path, "-t"]
        )
        guard status == 0 else {
            throw HarnessError.commandFailed("nginx -t (\(conf.lastPathComponent))", output: output)
        }
        return output
    }

    /// Runs nginx directly (daemon off, not launchd) so the test owns the process handle.
    func startNginx(conf: URL) throws {
        let name = conf.deletingPathExtension().lastPathComponent
        try launch(
            paths.nginxBinary,
            ["-p", paths.root.path, "-c", conf.path, "-g", "daemon off;"],
            log: paths.serviceLog("harness-nginx-\(name)")
        )
    }

    static func installedRealPHPVersion() -> String? {
        BundledPHP.availableVersions(php: AppSupportPaths().phpRuntimesRoot)
            .max { $0.compare($1, options: .numeric) == .orderedAscending }
    }

    /// Read-only symlink to the user's installed runtime; every php-fpm write (socket, pid,
    /// logs, ini) targets the temp root via the pool config.
    func linkRealPHPRuntime(version: String) throws {
        let real = AppSupportPaths().runtimeDir("php", version)
        try FileManager.default.createDirectory(
            at: paths.runtimeLangRoot("php"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: paths.runtimeDir("php", version),
            withDestinationURL: real
        )
    }

    /// Mirrors PHPFPMController.spec (same args/env), just foregrounded under the test.
    func startPHPFPM(version: String) throws {
        let poolConf = try PHPFPMPoolWriter().write(paths: paths, poolName: version)
        try? PHPIniStore(paths: paths).ensureSeeded(version: version)
        var args = ["-p", paths.root.path, "-y", poolConf.path, "-F"]
        let ini = paths.phpIni(version: version)
        if FileManager.default.fileExists(atPath: ini.path) {
            args += ["-c", ini.path]
        }
        try launch(
            paths.phpFpmBinary(version: version),
            args,
            environment: ["PHP_INI_SCAN_DIR": paths.phpExtConfDir(version: version).path],
            log: paths.phpFpmLog(version)
        )
        try waitForFile(paths.phpFpmSocket(version), logTailFrom: paths.phpFpmLog(version))
    }

    func waitForPort(_ port: Int, logTailFrom log: URL? = nil, timeout: TimeInterval = 10) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Self.canConnect(port: port) { return }
            usleep(100_000)
        }
        let tail = (try? String(contentsOf: log ?? paths.nginxErrorLog, encoding: .utf8)) ?? ""
        throw HarnessError.portNeverBound(port, errorLogTail: String(tail.suffix(2000)))
    }

    func waitForFile(_ url: URL, logTailFrom log: URL, timeout: TimeInterval = 10) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return }
            usleep(100_000)
        }
        let tail = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        throw HarnessError.fileNeverAppeared(url, logTail: String(tail.suffix(2000)))
    }

    static func probeFreePort() throws -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HarnessError.portProbeFailed }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0 else { throw HarnessError.portProbeFailed }
        let named = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        guard named == 0 else { throw HarnessError.portProbeFailed }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    static func canConnect(port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = UInt16(port).bigEndian
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    struct HTTPReply {
        let status: Int
        let headers: [String: String]
        let body: String

        func header(_ name: String) -> String? {
            headers[name.lowercased()]
        }
    }

    /// curl instead of URLSession: --resolve gives Host+SNI for a .test domain on loopback and
    /// --cacert trusts the harness-minted CA without touching any keychain.
    func request(
        scheme: String,
        domain: String,
        port: Int,
        path: String = "/",
        verifyWithLocalCA: Bool = false
    ) throws -> HTTPReply {
        let url = "\(scheme)://\(domain):\(port)\(path)"
        let id = UUID().uuidString.prefix(6)
        let headerFile = paths.run.appendingPathComponent("curl-\(id)-headers.txt")
        let bodyFile = paths.run.appendingPathComponent("curl-\(id)-body.txt")
        var args = [
            "-sS", "--max-time", "15",
            "--resolve", "\(domain):\(port):127.0.0.1",
            "-D", headerFile.path, "-o", bodyFile.path, url,
        ]
        if verifyWithLocalCA { args += ["--cacert", paths.caRootCert.path] }
        let (status, output) = try Self.run(URL(fileURLWithPath: "/usr/bin/curl"), args)
        guard status == 0 else {
            throw HarnessError.commandFailed("curl \(url)", output: output)
        }
        return try Self.parseReply(headerFile: headerFile, bodyFile: bodyFile)
    }

    static func parseReply(headerFile: URL, bodyFile: URL) throws -> HTTPReply {
        let rawHeaders = try String(contentsOf: headerFile, encoding: .utf8)
        let lines = rawHeaders.split(separator: "\r\n").map(String.init)
        let statusLine = lines.first ?? ""
        let status = Int(statusLine.split(separator: " ").dropFirst().first ?? "") ?? -1
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        let body = (try? String(contentsOf: bodyFile, encoding: .utf8)) ?? ""
        return HTTPReply(status: status, headers: headers, body: body)
    }
}
