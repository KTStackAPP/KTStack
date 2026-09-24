import Foundation

public struct ProcessWatchdog: Sendable {
    public static let command = "tunnel-watchdog"

    public let parentPID: pid_t
    public let deadline: Date?
    public let pollInterval: TimeInterval
    public let gracePeriod: TimeInterval

    public init(parentPID: pid_t, deadline: Date?, pollInterval: TimeInterval = 1, gracePeriod: TimeInterval = 5) {
        self.parentPID = parentPID
        self.deadline = deadline
        self.pollInterval = pollInterval
        self.gracePeriod = gracePeriod
    }

    public static func commandLine(parentPID: pid_t, deadline: Date?, executable: URL, arguments: [String]) -> [String] {
        var line = [command, "--parent-pid", String(parentPID)]
        if let deadline { line += ["--deadline", String(Int(deadline.timeIntervalSince1970))] }
        return line + ["--", executable.path] + arguments
    }

    public static func parse(_ arguments: [String]) -> (watchdog: ProcessWatchdog, executable: String, arguments: [String])? {
        guard let separator = arguments.firstIndex(of: "--"), separator + 1 < arguments.count else { return nil }
        let options = Array(arguments[..<separator])
        var parent: pid_t?
        var deadline: Date?
        var index = 0
        while index + 1 < options.count {
            switch options[index] {
            case "--parent-pid": parent = pid_t(options[index + 1])
            case "--deadline": deadline = TimeInterval(options[index + 1]).map(Date.init(timeIntervalSince1970:))
            default: return nil
            }
            index += 2
        }
        guard index == options.count, let parent, parent > 1 else { return nil }
        let program = Array(arguments[(separator + 1)...])
        return (ProcessWatchdog(parentPID: parent, deadline: deadline), program[0], Array(program.dropFirst()))
    }

    public func shouldStop(now: Date = Date()) -> Bool {
        if let deadline, now >= deadline { return true }
        return !Self.isAlive(parentPID)
    }

    public func run(executable: String, arguments: [String], forwardTermination: Bool = true) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do { try process.run() } catch { return 127 }
        var termination: DispatchSourceSignal?
        if forwardTermination {
            signal(SIGTERM, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
            source.setEventHandler { stop(process) }
            source.resume()
            termination = source
        }
        while process.isRunning {
            if shouldStop() {
                stop(process)
                break
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        process.waitUntilExit()
        termination?.cancel()
        return process.terminationStatus
    }

    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let limit = Date().addingTimeInterval(gracePeriod)
        while process.isRunning, Date() < limit {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
