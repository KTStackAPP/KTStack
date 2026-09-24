import Foundation

extension LaunchdServiceRunner {
    var ownedPorts: [Int] {
        var ports = preflightPorts
        let healthProbe: HealthProbe = probe
        if case let .tcp(port) = healthProbe, !ports.contains(port) { ports.append(port) }
        return ports
    }

    func verifyPortOwnership(listeners: (Int) -> [pid_t]? = PortOwnership.listenerPIDs) throws {
        guard let jobPID = agents.jobPID(label) else { return }
        for port in ownedPorts {
            guard let owners = listeners(port), !owners.isEmpty else { continue }
            guard !PortOwnership.isOwned(by: jobPID, listeners: owners) else { continue }
            let other = owners.first.flatMap { ProcessName.of($0) } ?? "another process"
            diag.log(.error, "\(kind.displayName) port \(port) answered by \(other) (pids \(owners)), job pid \(jobPID)")
            try? agents.bootout(label)
            throw Self.error(
                "\(kind.displayName) could not take port \(port): it is answered by \(other), not by KTStack's "
                    + "\(kind.displayName). Stop that process or change the port, then start again."
            )
        }
    }
}

enum ProcessName {
    static func of(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer)).lastPathComponent
    }
}
