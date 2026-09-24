import Foundation

struct BlockingProcess {
    let request: ProcessRequest
    let terminationGrace: TimeInterval
    let drainGrace: TimeInterval

    func run() throws -> ProcessResult {
        guard request.executable.hasPrefix("/") else {
            throw ProcessRunnerError.executableNotAbsolute(request.executable)
        }
        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = request.standardInput.map { _ in Pipe() }
        let pid: pid_t
        do {
            pid = try spawn(stdout: stdout, stderr: stderr, stdin: stdin)
        } catch {
            [stdout, stderr].forEach(Self.closeAll)
            if let stdin { Self.closeAll(stdin) }
            throw error
        }
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()
        try? stdin?.fileHandleForReading.close()
        if let stdin, let data = request.standardInput { StandardInputFeeder.feed(data, into: stdin) }

        let watchdog = request.timeout.map { TimeoutWatchdog(pid: pid, timeout: $0, grace: terminationGrace) }
        let output = PipeDrainThread(stdout.fileHandleForReading)
        let errorOutput = PipeDrainThread(stderr.fileHandleForReading)
        let status = Self.reap(pid)
        let interruption = watchdog?.finish()
        let deadline = DispatchTime.now() + drainGrace
        return ProcessResult(
            status: status,
            stdout: output.wait(until: deadline),
            stderr: errorOutput.wait(until: deadline),
            interruption: interruption
        )
    }

    private func spawn(stdout: Pipe, stderr: Pipe, stdin: Pipe?) throws -> pid_t {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        if let stdin {
            posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, 0)
        } else {
            posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        }
        posix_spawn_file_actions_adddup2(&actions, stdout.fileHandleForWriting.fileDescriptor, 1)
        posix_spawn_file_actions_adddup2(&actions, stderr.fileHandleForWriting.fileDescriptor, 2)
        if let directory = request.currentDirectory {
            posix_spawn_file_actions_addchdir_np(&actions, directory.path)
        }

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for signal in 1 ..< SIGSYS where signal != SIGKILL && signal != SIGSTOP {
            sigaddset(&defaults, signal)
        }
        posix_spawnattr_setsigdefault(&attributes, &defaults)
        var mask = sigset_t()
        sigemptyset(&mask)
        posix_spawnattr_setsigmask(&attributes, &mask)
        let flags = POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))

        let environment = request.environment ?? ProcessInfo.processInfo.environment
        var argv = ([request.executable] + request.arguments).map { strdup($0) } + [nil]
        var envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }
        var pid: pid_t = 0
        let code = posix_spawn(&pid, request.executable, &actions, &attributes, &argv, &envp)
        guard code == 0 else {
            throw ProcessRunnerError.launchFailed(request.executable, String(cString: strerror(code)))
        }
        return pid
    }

    private static func reap(_ pid: pid_t) -> Int32 {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1, errno == EINTR {}
        let signal = status & 0x7F
        return signal == 0 ? (status >> 8) & 0xFF : signal
    }

    private static func closeAll(_ pipe: Pipe) {
        try? pipe.fileHandleForReading.close()
        try? pipe.fileHandleForWriting.close()
    }
}

private final class PipeDrainThread: @unchecked Sendable {
    private let lock = NSLock()
    private let done = DispatchSemaphore(value: 0)
    private var data = Data()

    init(_ handle: FileHandle) {
        Thread { [self] in
            let descriptor = handle.fileDescriptor
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                let count = read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    lock.lock()
                    data.append(contentsOf: buffer[0 ..< count])
                    lock.unlock()
                } else if count == 0 || errno != EINTR {
                    break
                }
            }
            try? handle.close()
            done.signal()
        }.start()
    }

    func wait(until deadline: DispatchTime) -> Data {
        _ = done.wait(timeout: deadline)
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

private enum StandardInputFeeder {
    static func feed(_ data: Data, into pipe: Pipe) {
        let handle = pipe.fileHandleForWriting
        _ = fcntl(handle.fileDescriptor, F_SETNOSIGPIPE, 1)
        Thread {
            try? handle.write(contentsOf: data)
            try? handle.close()
        }.start()
    }
}

private final class TimeoutWatchdog: @unchecked Sendable {
    private let lock = NSLock()
    private let exited = DispatchSemaphore(value: 0)
    private var finished = false
    private var fired = false

    init(pid: pid_t, timeout: TimeInterval, grace: TimeInterval) {
        Thread { [self] in
            guard exited.wait(timeout: .now() + timeout) == .timedOut, send(SIGTERM, to: pid) else { return }
            guard exited.wait(timeout: .now() + grace) == .timedOut else { return }
            _ = send(SIGKILL, to: pid)
        }.start()
    }

    func finish() -> ProcessInterruption? {
        lock.lock()
        finished = true
        let timedOut = fired
        lock.unlock()
        exited.signal()
        return timedOut ? .timedOut : nil
    }

    private func send(_ signal: Int32, to pid: pid_t) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        fired = true
        kill(pid, signal)
        return true
    }
}
