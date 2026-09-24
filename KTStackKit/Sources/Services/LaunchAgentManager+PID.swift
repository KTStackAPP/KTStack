import Foundation

extension LaunchAgentManager {
    public func jobPID(_ label: String) -> pid_t? {
        let res = Self.launchctl(["print", "\(Self.guiDomain)/\(label)"])
        guard res.code == 0 else { return nil }
        return Self.parsePID(from: res.out)
    }

    static func parsePID(from output: String) -> pid_t? {
        for raw in output.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid = ") else { continue }
            return pid_t(line.dropFirst("pid = ".count).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}
