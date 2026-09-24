import Darwin
import Foundation

enum FileDescriptorCounter {
    static func openCount(pid: pid_t = getpid()) -> Int {
        let entrySize = MemoryLayout<proc_fdinfo>.stride
        let required = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard required > 0 else { return -1 }
        let capacity = Int(required) / entrySize + 32
        var entries = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let written = entries.withUnsafeMutableBytes { raw in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, raw.baseAddress, Int32(raw.count))
        }
        guard written > 0 else { return -1 }
        return Int(written) / entrySize
    }

    static func delta(_ body: () throws -> Void) rethrows -> Int {
        let before = openCount()
        try body()
        return openCount() - before
    }

    static func delta(_ body: () async throws -> Void) async rethrows -> Int {
        let before = openCount()
        try await body()
        return openCount() - before
    }
}
