import Foundation

public enum ProcessInterruption: Sendable, Equatable {
    case timedOut
    case cancelled
}

public struct ProcessResult: Sendable, Equatable {
    public let status: Int32
    public let stdout: Data
    public let stderr: Data
    public let interruption: ProcessInterruption?

    public init(status: Int32, stdout: Data, stderr: Data, interruption: ProcessInterruption?) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.interruption = interruption
    }

    public var succeeded: Bool {
        status == 0 && interruption == nil
    }

    public var stdoutText: String {
        String(decoding: stdout, as: UTF8.self)
    }

    public var stderrText: String {
        String(decoding: stderr, as: UTF8.self)
    }
}

public enum ProcessRunnerError: LocalizedError, Equatable {
    case executableNotAbsolute(String)
    case launchFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case let .executableNotAbsolute(path):
            "Refusing to run \(path): the executable path must be absolute."
        case let .launchFailed(path, reason):
            "Could not launch \(path): \(reason)"
        }
    }
}

public struct ProcessRequest: Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]?
    public let currentDirectory: URL?
    public let standardInput: Data?
    public let timeout: TimeInterval?

    public init(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        standardInput: Data? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.currentDirectory = currentDirectory
        self.standardInput = standardInput
        self.timeout = timeout
    }
}
