import Darwin
import Foundation

public enum RelaunchGate {
    public static let flag = "--wait-for-pid"

    public static func arguments(waitingFor pid: pid_t) -> [String] {
        [flag, String(pid)]
    }

    public static func pidToWaitFor(in arguments: [String]) -> pid_t? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        guard let pid = pid_t(arguments[index + 1]), pid > 0, pid != getpid() else { return nil }
        return pid
    }

    @discardableResult
    public static func waitForExit(
        of pid: pid_t,
        timeout: TimeInterval,
        isAlive: (pid_t) -> Bool = processIsAlive
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while isAlive(pid) {
            guard Date() < deadline else { return false }
            usleep(50000)
        }
        return true
    }

    static func processIsAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
