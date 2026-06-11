import Foundation

/// Thin supervisor around `Process` for a single long-running foreground daemon
/// (nginx master, php-fpm master). Captures stdout/stderr to a log file, exposes a
/// termination callback, and guarantees a clean stop.
///
/// Teardown: `stop()` signals the master, which reaps its own workers on SIGTERM/SIGQUIT
/// (nginx and php-fpm both do this), then escalates to SIGKILL if the master is still alive
/// past the grace period. This is what backs the "no orphaned processes on quit" criterion
/// for this phase's dev shim.
public final class ManagedProcess: @unchecked Sendable {
    public enum State: Equatable, Sendable { case idle, running, stopped(code: Int32), failed(String) }

    public let label: String
    private let executable: URL
    private let arguments: [String]
    private let workingDirectory: URL?
    private let environment: [String: String]?
    private let logFile: URL?

    private let lock = NSLock()
    private var process: Process?
    private var logHandle: FileHandle?

    /// Invoked off the main thread when the process exits (clean or crash).
    public var onTerminate: (@Sendable (State) -> Void)?

    public init(label: String,
                executable: URL,
                arguments: [String],
                workingDirectory: URL? = nil,
                environment: [String: String]? = nil,
                logFile: URL? = nil) {
        self.label = label
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.logFile = logFile
    }

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return process?.isRunning ?? false
    }

    public var processIdentifier: Int32? {
        lock.lock(); defer { lock.unlock() }
        guard let p = process, p.isRunning else { return nil }
        return p.processIdentifier
    }

    /// Launch the daemon. Throws if the binary is missing/not executable or `Process` fails.
    public func start() throws {
        lock.lock(); defer { lock.unlock() }
        guard process == nil else { throw ProcessError.alreadyRunning(label) }

        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProcessError.notExecutable(executable.path)
        }

        let proc = Process()
        proc.executableURL = executable
        proc.arguments = arguments
        if let wd = workingDirectory { proc.currentDirectoryURL = wd }
        if let env = environment { proc.environment = env }

        if let logFile {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                logHandle = handle
                proc.standardOutput = handle
                proc.standardError = handle
            }
        }

        proc.terminationHandler = { [weak self] p in
            guard let self else { return }
            let state: State = p.terminationReason == .exit && p.terminationStatus == 0
                ? .stopped(code: 0)
                : (p.terminationReason == .uncaughtSignal
                    ? .failed("terminated by signal \(p.terminationStatus)")
                    : .stopped(code: p.terminationStatus))
            self.lock.lock()
            self.process = nil
            try? self.logHandle?.close()
            self.logHandle = nil
            self.lock.unlock()
            self.onTerminate?(state)
        }

        do {
            try proc.run()
        } catch {
            try? logHandle?.close(); logHandle = nil
            throw ProcessError.launchFailed(label, error.localizedDescription)
        }
        process = proc
    }

    /// Graceful stop: SIGTERM the process group, wait briefly, SIGKILL if still alive.
    public func stop(gracePeriod: TimeInterval = 3.0) {
        lock.lock()
        guard let proc = process, proc.isRunning else { lock.unlock(); return }
        let pid = proc.processIdentifier
        lock.unlock()

        kill(pid, SIGTERM)          // master reaps its workers on SIGTERM

        let deadline = Date().addingTimeInterval(gracePeriod)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            kill(pid, SIGKILL)
            proc.waitUntilExit()
        }
    }

    public enum ProcessError: LocalizedError {
        case alreadyRunning(String)
        case notExecutable(String)
        case launchFailed(String, String)

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning(let l): return "\(l) is already running."
            case .notExecutable(let p):  return "Binary is missing or not executable: \(p)"
            case .launchFailed(let l, let m): return "Failed to launch \(l): \(m)"
            }
        }
    }
}
