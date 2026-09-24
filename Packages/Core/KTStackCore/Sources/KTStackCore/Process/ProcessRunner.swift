import Foundation

public struct ProcessRunner: Sendable {
    public let terminationGrace: TimeInterval
    public let drainGrace: TimeInterval

    public init(terminationGrace: TimeInterval = 2, drainGrace: TimeInterval = 2) {
        self.terminationGrace = terminationGrace
        self.drainGrace = drainGrace
    }

    public func run(_ request: ProcessRequest) throws -> ProcessResult {
        let execution = try makeExecution(request)
        let done = DispatchSemaphore(value: 0)
        let box = ResultBox()
        try execution.start { result in
            box.set(result)
            done.signal()
        }
        done.wait()
        return box.value!
    }

    public func run(
        _ executable: String,
        _ arguments: [String] = [],
        timeout: TimeInterval? = nil
    ) throws -> ProcessResult {
        try run(ProcessRequest(executable: executable, arguments: arguments, timeout: timeout))
    }

    public func runAsync(_ request: ProcessRequest) async throws -> ProcessResult {
        let execution = try makeExecution(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try execution.start { continuation.resume(returning: $0) }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            execution.interrupt(.cancelled)
        }
    }

    public func runAsync(
        _ executable: String,
        _ arguments: [String] = [],
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        try await runAsync(ProcessRequest(executable: executable, arguments: arguments, timeout: timeout))
    }

    private func makeExecution(_ request: ProcessRequest) throws -> ProcessExecution {
        try ProcessExecution(request: request, terminationGrace: terminationGrace, drainGrace: drainGrace)
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: ProcessResult?

    var value: ProcessResult? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ result: ProcessResult) {
        lock.lock()
        stored = result
        lock.unlock()
    }
}
