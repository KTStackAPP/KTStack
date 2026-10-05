import Foundation

public extension WorkerSupervisor {
    func run(
        executable: String,
        arguments: [String],
        stop: WorkerStopSignal = WorkerStopSignal(),
        listensForTermination: Bool = true
    ) -> Int32 {
        let termination = listensForTermination ? stop.listenForTermination() : nil
        defer { termination?.cancel() }
        var policy = backoff
        var status = WorkerStatus(state: .running)
        supervise: while !shouldStop(stop) {
            let started = Date()
            if let process = launch(executable, arguments) {
                status.state = .running
                status.pid = process.processIdentifier
                status.nextAttemptAt = nil
                publish(&status)
                guard !waitForExit(process, stop: stop) else { break supervise }
                status.lastExitStatus = process.terminationStatus
                report("worker exited with status \(process.terminationStatus)")
            } else {
                status.lastExitStatus = 127
                report("cannot start \(executable): not found or not executable")
            }
            status.pid = nil
            switch policy.record(runtime: Date().timeIntervalSince(started)) {
            case .giveUp:
                status.state = .crashed
                publish(&status)
                report("worker keeps exiting; giving up after \(policy.quickExits) quick exits")
                return 0
            case let .restart(delay):
                status.restarts += 1
                status.state = .backoff
                status.nextAttemptAt = Date().addingTimeInterval(delay)
                publish(&status)
                report("restarting in \(Self.formatted(delay))")
                guard pause(delay, stop: stop) else { break supervise }
            }
        }
        status.state = .stopped
        status.pid = nil
        status.nextAttemptAt = nil
        publish(&status)
        return 0
    }

    private func launch(_ executable: String, _ arguments: [String]) -> Process? {
        let environment = ProcessInfo.processInfo.environment
        let directory = FileManager.default.currentDirectoryPath
        guard let path = WorkerExecutable.resolve(executable, searchPath: environment["PATH"], workingDirectory: directory) else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
            return process
        } catch {
            return nil
        }
    }

    private func waitForExit(_ process: Process, stop: WorkerStopSignal) -> Bool {
        while process.isRunning {
            if shouldStop(stop) {
                terminate(process)
                return true
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        process.waitUntilExit()
        return false
    }

    private func terminate(_ process: Process) {
        process.terminate()
        let limit = Date().addingTimeInterval(gracePeriod)
        while process.isRunning, Date() < limit {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        process.waitUntilExit()
    }

    private func pause(_ delay: TimeInterval, stop: WorkerStopSignal) -> Bool {
        let until = Date().addingTimeInterval(delay)
        while Date() < until {
            if shouldStop(stop) { return false }
            Thread.sleep(forTimeInterval: max(0, min(pollInterval, until.timeIntervalSinceNow)))
        }
        return !shouldStop(stop)
    }

    private func publish(_ status: inout WorkerStatus) {
        status.updatedAt = Date()
        status.write(to: statusURL)
    }

    private static func formatted(_ delay: TimeInterval) -> String {
        delay < 1 ? String(format: "%.2fs", delay) : "\(Int(delay.rounded()))s"
    }
}
