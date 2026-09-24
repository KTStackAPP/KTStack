import Foundation

enum CLIVersion {
    static func current(executable: URL = URL(fileURLWithPath: CommandLine.arguments.first ?? "")) -> String {
        guard let info = infoDictionary(executable: executable),
              let short = info["CFBundleShortVersionString"] as? String
        else { return "unknown" }
        guard let build = info["CFBundleVersion"] as? String else { return short }
        return "\(short) (build \(build))"
    }

    static func infoDictionary(executable: URL) -> [String: Any]? {
        let resolved = executable.resolvingSymlinksInPath()
        let contents = resolved.deletingLastPathComponent().deletingLastPathComponent()
        let plist = contents.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plist) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
