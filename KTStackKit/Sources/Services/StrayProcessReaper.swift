import Foundation
import KTStackCore

enum StrayProcessReaper {
    static func pids(matching programPath: String) -> [Int32] {
        let me = getpid()
        return ProcessLookup.pids(executablePath: programPath).filter { $0 != me }
    }

    static func terminate(_ pids: [Int32], graceSeconds: TimeInterval = 5) {
        guard !pids.isEmpty else { return }
        for pid in pids {
            kill(pid, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(graceSeconds)
        while Date() < deadline {
            if pids.allSatisfy({ kill($0, 0) != 0 }) { return }
            usleep(200_000)
        }
        for pid in pids where kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }
    }
}
