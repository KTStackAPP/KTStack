import Foundation
import KTStackCore

public struct TunnelWatchdogLaunch: Sendable, Equatable {
    public let executable: URL
    public let deadline: Date?

    public init(executable: URL, deadline: Date?) {
        self.executable = executable
        self.deadline = deadline
    }

    public func wrap(binary: URL, arguments: [String], parentPID: pid_t = getpid()) -> (binary: URL, arguments: [String]) {
        let line = ProcessWatchdog.commandLine(parentPID: parentPID, deadline: deadline, executable: binary, arguments: arguments)
        return (executable, line)
    }
}
