import Foundation
import KTStackCore

public struct LaunchAgentSpec: Sendable, Equatable {
    public let label: String
    public let programArguments: [String]
    public let workingDirectory: String?
    public let environment: [String: String]
    public let stdoutPath: String?
    public let stderrPath: String?
    public let fileDescriptorLimit: Int?

    public let keepAliveOnCrash: Bool
    public let runAtLoad: Bool

    public init(
        label: String,
        programArguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        stdoutPath: String? = nil,
        stderrPath: String? = nil,
        fileDescriptorLimit: Int? = nil,
        keepAliveOnCrash: Bool = true,
        runAtLoad: Bool = true
    ) {
        self.label = label
        self.programArguments = programArguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.fileDescriptorLimit = fileDescriptorLimit
        self.keepAliveOnCrash = keepAliveOnCrash
        self.runAtLoad = runAtLoad
    }
}

public struct LaunchAgentManager: Sendable {
    public enum LaunchError: LocalizedError {
        case commandFailed(String, Int32, String)
        public var errorDescription: String? {
            switch self {
            case let .commandFailed(op, code, out):
                "launchctl \(op) failed (\(code)): \(out)"
            }
        }
    }

    private let paths: AppSupportPaths
    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    private static let loadedCache = LoadedLabelsCache()

    public static var guiDomain: String {
        "gui/\(getuid())"
    }

    public func plistData(for spec: LaunchAgentSpec) throws -> Data {
        var dict: [String: Any] = [
            "Label": spec.label,
            "ProgramArguments": spec.programArguments,
            "RunAtLoad": spec.runAtLoad,
            "ProcessType": "Interactive",
            "ThrottleInterval": 10,
        ]
        if let wd = spec.workingDirectory { dict["WorkingDirectory"] = wd }
        if !spec.environment.isEmpty { dict["EnvironmentVariables"] = spec.environment }
        if let out = spec.stdoutPath { dict["StandardOutPath"] = out }
        if let err = spec.stderrPath { dict["StandardErrorPath"] = err }
        if let limit = spec.fileDescriptorLimit {
            let limits = ["NumberOfFiles": limit]
            dict["SoftResourceLimits"] = limits
            dict["HardResourceLimits"] = limits
        }

        if spec.keepAliveOnCrash { dict["KeepAlive"] = ["SuccessfulExit": false] }
        return try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    }

    @discardableResult
    public func writePlist(for spec: LaunchAgentSpec) throws -> URL {
        try paths.ensureDirectoryTree()
        let url = paths.launchAgentPlist(spec.label)
        try plistData(for: spec).write(to: url, options: .atomic)
        return url
    }

    public func bootstrap(_ spec: LaunchAgentSpec) throws {
        let plist = try writeBootstrapPlist(for: spec)
        if Self.loadedCache.containsNow(spec.label) { return }
        try run("bootstrap", [Self.guiDomain, plist.path])
        Self.loadedCache.markLoaded(spec.label)
    }

    public func kickstart(_ label: String) throws {
        try run("kickstart", ["-k", "\(Self.guiDomain)/\(label)"])
    }

    public func bootout(_ label: String) throws {
        guard Self.loadedCache.containsNow(label) else { return }
        try run("bootout", ["\(Self.guiDomain)/\(label)"])
        Self.loadedCache.markUnloaded(label)
    }

    public func isLoaded(_ label: String) -> Bool {
        Self.loadedCache.contains(label)
    }

    public func isLoadedNow(_ label: String) -> Bool {
        Self.loadedCache.containsNow(label)
    }

    public func bootoutAll() {
        for label in Self.loadedLabels() {
            try? run("bootout", ["\(Self.guiDomain)/\(label)"])
        }
        Self.loadedCache.invalidate()
    }

    public func loadedLabels(withPrefix prefix: String) -> [String] {
        Self.loadedLabels(prefix: prefix).sorted()
    }

    public func bootout(matchingPrefix prefix: String) {
        for label in Self.loadedLabels(prefix: prefix) {
            try? run("bootout", ["\(Self.guiDomain)/\(label)"])
        }
        Self.loadedCache.invalidate()
    }

    public func diagnostics() -> ServiceDiagnostics {
        ServiceDiagnostics(paths: paths)
    }

    private func run(_ op: String, _ args: [String]) throws {
        let res = Self.launchctl([op] + args)
        let diag = ServiceDiagnostics(paths: paths)
        let cmd = "launchctl \(op) \(args.joined(separator: " "))"
        let out = res.out.trimmingCharacters(in: .whitespacesAndNewlines)

        switch res.code {
        case 0:
            diag.log(.info, "\(cmd) → ok")
        // 5 is launchctl's "already loaded / no such process" for bootstrap/bootout; we treat it as
        // success but record it, since a spurious 5 on bootstrap means the job never actually loaded.
        case 5:
            diag.log(.warn, "\(cmd) → rc=5 (treated as already-loaded): \(out)")
        default:
            diag.log(.error, "\(cmd) → rc=\(res.code): \(out)")
            throw LaunchError.commandFailed(op, res.code, res.out)
        }
    }

    static func loadedLabels(prefix: String = "com.ktstack.") -> Set<String> {
        parseLoadedLabels(from: launchctl(["print", guiDomain]).out, prefix: prefix)
    }

    static func parseLoadedLabels(from output: String, prefix: String = "com.ktstack.") -> Set<String> {
        var labels = Set<String>()
        var inServices = false
        var depth = 0
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !inServices {
                if line.hasPrefix("services = {") { inServices = true; depth = 1 }
                continue
            }
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth <= 0 { break }
            if let token = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last,
               token.hasPrefix(prefix),
               !token.contains("-sparkle-")
            {
                labels.insert(String(token))
            }
        }
        return labels
    }

    static func launchctl(_ args: [String]) -> (code: Int32, out: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do { try proc.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return (proc.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
