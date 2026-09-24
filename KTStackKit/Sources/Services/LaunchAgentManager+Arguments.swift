import Foundation

extension LaunchAgentManager {
    public func loadedProgramArguments(_ label: String) -> [String]? {
        let res = Self.launchctl(["print", "\(Self.guiDomain)/\(label)"])
        guard res.code == 0 else { return nil }
        return Self.parseArguments(from: res.out)
    }

    static func parseArguments(from output: String) -> [String]? {
        var collecting = false
        var arguments: [String] = []
        for raw in output.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !collecting {
                if line == "arguments = {" { collecting = true }
                continue
            }
            if line == "}" { return arguments }
            arguments.append(line)
        }
        return nil
    }
}
