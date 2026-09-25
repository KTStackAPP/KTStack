import Darwin
import Foundation
import KTStackCore

enum PortOwnership {
    static func listenerPIDs(port: Int) -> [pid_t]? {
        let args = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "p"]
        guard let res = try? ProcessRunner().run("/usr/sbin/lsof", args, timeout: ToolTimeout.processQuery),
              res.interruption == nil else { return nil }
        return res.stdoutText.split(separator: "\n").compactMap { line in
            line.hasPrefix("p") ? pid_t(line.dropFirst()) : nil
        }
    }

    static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    static func isOwned(by jobPID: pid_t, listeners: [pid_t]) -> Bool {
        listeners.contains { $0 == jobPID || parentPID(of: $0) == jobPID }
    }
}
