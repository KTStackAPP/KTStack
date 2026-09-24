import Foundation
import KTStackCore

public struct SiteFolderDeletionPolicy: Sendable {
    static let userFolderNames = [
        "Desktop", "Documents", "Downloads", "Library", "Movies", "Music", "Pictures", "Public",
        "Applications", "Developer", "Sites", "iCloud Drive", "Dropbox",
    ]
    static let systemTrees = [
        "/System", "/Library", "/Applications", "/usr", "/bin", "/sbin", "/etc", "/opt",
        "/private/etc", "/private/var/db", "/cores",
    ]

    let home: String
    let ktstackRoot: String
    let sitesRoot: String

    public init(home: URL, ktstackRoot: URL, sitesRoot: URL) {
        self.home = Self.canonical(home.path)
        self.ktstackRoot = Self.canonical(ktstackRoot.path)
        self.sitesRoot = Self.canonical(sitesRoot.path)
    }

    public static func standard(defaults: UserDefaults = .standard) -> SiteFolderDeletionPolicy {
        let sitesRoot = defaults.string(forKey: "KTStack.sitesRootPath") ?? AppSupportPaths.defaultSitesRoot.path
        return SiteFolderDeletionPolicy(
            home: FileManager.default.homeDirectoryForCurrentUser,
            ktstackRoot: AppSupportPaths().root,
            sitesRoot: URL(fileURLWithPath: sitesRoot, isDirectory: true)
        )
    }

    public func isProtected(_ folder: URL) -> Bool {
        let path = Self.canonical(folder.path)
        let components = path.split(separator: "/")
        if components.count < 2 { return true }
        if components.first == "volumes", components.count < 3 { return true }
        if Self.isSameOrAncestor(path, of: home) || Self.isSameOrAncestor(path, of: sitesRoot) { return true }
        if Self.isSameOrAncestor(path, of: ktstackRoot) || Self.isSameOrAncestor(ktstackRoot, of: path) { return true }
        if Self.userFolderNames.contains(where: { path == Self.join(home, $0) }) { return true }
        return Self.systemTrees.contains { Self.isSameOrAncestor(Self.canonical($0), of: path) }
    }

    public func deletionBlocker(for folder: URL, otherSitePaths: [String]) -> String? {
        if isProtected(folder) { return Self.canonical(folder.path) }
        let path = Self.canonical(folder.path)
        let clash = otherSitePaths.map(Self.canonical).first { Self.isSameOrAncestor(path, of: $0) }
        return clash.map { _ in path }
    }

    public static func canonical(_ raw: String) -> String {
        var path = URL(fileURLWithPath: raw).standardizedFileURL.path
        if let resolved = realpath(path, nil) {
            path = String(cString: resolved)
            free(resolved)
        }
        let dataVolume = "/System/Volumes/Data"
        if path.hasPrefix(dataVolume + "/") { path = String(path.dropFirst(dataVolume.count)) }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.lowercased()
    }

    static func isSameOrAncestor(_ candidate: String, of path: String) -> Bool {
        candidate == path || candidate == "/" || path.hasPrefix(candidate + "/")
    }

    private static func join(_ base: String, _ name: String) -> String {
        base == "/" ? "/" + name.lowercased() : base + "/" + name.lowercased()
    }
}
