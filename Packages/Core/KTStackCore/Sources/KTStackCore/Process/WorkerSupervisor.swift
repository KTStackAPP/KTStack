import Foundation

public struct WorkerSupervisor: Sendable {
    public static let command = "worker-supervise"

    public let parentPID: pid_t
    public let statusURL: URL
    public let backoff: WorkerBackoff
    public let pollInterval: TimeInterval
    public let gracePeriod: TimeInterval

    public init(
        parentPID: pid_t,
        statusURL: URL,
        backoff: WorkerBackoff = WorkerBackoff(),
        pollInterval: TimeInterval = 0.5,
        gracePeriod: TimeInterval = 10
    ) {
        self.parentPID = parentPID
        self.statusURL = statusURL
        self.backoff = backoff
        self.pollInterval = pollInterval
        self.gracePeriod = gracePeriod
    }

    public static func commandLine(parentPID: pid_t, statusURL: URL, executable: String, arguments: [String]) -> [String] {
        [command, "--parent-pid", String(parentPID), "--status", statusURL.path, "--", executable] + arguments
    }

    public static func parse(_ arguments: [String]) -> (supervisor: WorkerSupervisor, executable: String, arguments: [String])? {
        guard let separator = arguments.firstIndex(of: "--"), separator + 1 < arguments.count else { return nil }
        let options = Array(arguments[..<separator])
        var parent: pid_t?
        var status: URL?
        var index = 0
        while index + 1 < options.count {
            switch options[index] {
            case "--parent-pid": parent = pid_t(options[index + 1])
            case "--status": status = URL(fileURLWithPath: options[index + 1])
            default: return nil
            }
            index += 2
        }
        guard index == options.count, let parent, parent > 1, let status else { return nil }
        let program = Array(arguments[(separator + 1)...])
        return (WorkerSupervisor(parentPID: parent, statusURL: status), program[0], Array(program.dropFirst()))
    }

    func shouldStop(_ stop: WorkerStopSignal) -> Bool {
        stop.isRequested || !ProcessWatchdog.isAlive(parentPID)
    }

    func report(_ message: String) {
        fputs("[ktstack] \(message)\n", stderr)
    }
}

public final class WorkerStopSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var requested = false

    public init() {}

    public var isRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    public func request() {
        lock.lock()
        requested = true
        lock.unlock()
    }

    func listenForTermination() -> DispatchSourceSignal {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        source.setEventHandler { [weak self] in self?.request() }
        source.resume()
        return source
    }
}

public enum WorkerExecutable {
    public static func resolve(_ name: String, searchPath: String?, workingDirectory: String) -> String? {
        let fm = FileManager.default
        if name.contains("/") {
            let path = name.hasPrefix("/")
                ? name
                : URL(fileURLWithPath: workingDirectory).appendingPathComponent(name).standardizedFileURL.path
            return fm.isExecutableFile(atPath: path) ? path : nil
        }
        let directories = (searchPath ?? "/usr/bin:/bin").split(separator: ":").map(String.init)
        for directory in directories where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
