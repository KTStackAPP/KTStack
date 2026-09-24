import Foundation

final class ProcessExecution: @unchecked Sendable {
    private let request: ProcessRequest
    private let terminationGrace: TimeInterval
    private let drainGrace: TimeInterval
    private let process = Process()
    private let drains = DispatchGroup()
    private let stdout: PipeCollector
    private let stderr: PipeCollector
    private let lock = NSLock()
    private var interruption: ProcessInterruption?
    private var started = false
    private var exited = false
    private var completed = false
    private var completion: ((ProcessResult) -> Void)?

    init(request: ProcessRequest, terminationGrace: TimeInterval, drainGrace: TimeInterval) throws {
        guard request.executable.hasPrefix("/") else {
            throw ProcessRunnerError.executableNotAbsolute(request.executable)
        }
        self.request = request
        self.terminationGrace = terminationGrace
        self.drainGrace = drainGrace
        stdout = PipeCollector(group: drains)
        stderr = PipeCollector(group: drains)
    }

    func start(completion: @escaping (ProcessResult) -> Void) throws {
        self.completion = completion
        process.executableURL = URL(fileURLWithPath: request.executable)
        process.arguments = request.arguments
        if let environment = request.environment { process.environment = environment }
        if let directory = request.currentDirectory { process.currentDirectoryURL = directory }
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe
        let input = request.standardInput.map { _ in Pipe() }
        process.standardInput = input ?? FileHandle.nullDevice
        process.terminationHandler = { [self] _ in processExited() }
        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            _ = stdout.detach()
            _ = stderr.detach()
            self.completion = nil
            throw ProcessRunnerError.launchFailed(request.executable, error.localizedDescription)
        }
        lock.lock()
        started = true
        let pendingInterruption = interruption != nil
        lock.unlock()
        if pendingInterruption { escalate() }
        if let input, let data = request.standardInput { feed(data, into: input) }
        if let timeout = request.timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in interrupt(.timedOut) }
        }
    }

    func interrupt(_ reason: ProcessInterruption) {
        lock.lock()
        guard !completed, !exited, interruption == nil else {
            lock.unlock()
            return
        }
        interruption = reason
        let launched = started
        lock.unlock()
        if launched { escalate() }
    }

    private func escalate() {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + terminationGrace) { [self] in
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }

    private func feed(_ data: Data, into pipe: Pipe) {
        DispatchQueue.global().async {
            let handle = pipe.fileHandleForWriting
            _ = fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1)
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
    }

    private func processExited() {
        lock.lock()
        exited = true
        lock.unlock()
        drains.notify(queue: .global()) { [self] in finish() }
        DispatchQueue.global().asyncAfter(deadline: .now() + drainGrace) { [self] in finish() }
    }

    private func finish() {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let reason = interruption
        let callback = completion
        completion = nil
        lock.unlock()
        process.terminationHandler = nil
        let result = ProcessResult(
            status: process.terminationStatus,
            stdout: stdout.detach(),
            stderr: stderr.detach(),
            interruption: reason
        )
        callback?(result)
    }
}
