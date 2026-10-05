import Foundation

struct SiteFileCollector {
    let matcher: ExcludeMatcher
    var fileManager: FileManager = .default

    func collect(root: URL) throws -> [String] {
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw BackupPipelineError.invalidArchive("Site folder \(root.path) doesn't exist.")
        }
        return try walk(resolvedRoot, relative: "", root: resolvedRoot)
    }

    private func walk(_ directory: URL, relative: String, root: URL) throws -> [String] {
        var collected: [String] = []
        let names = try fileManager.contentsOfDirectory(atPath: directory.path).sorted()
        for name in names {
            let relativePath = relative.isEmpty ? name : "\(relative)/\(name)"
            guard !matcher.isExcluded(relativePath) else { continue }
            let url = directory.appendingPathComponent(name)
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if values.isSymbolicLink == true {
                if pointsInside(url, root: root) { collected.append(relativePath) }
                continue
            }
            collected.append(relativePath)
            if values.isDirectory == true {
                collected += try walk(url, relative: relativePath, root: root)
            }
        }
        return collected
    }

    private func pointsInside(_ link: URL, root: URL) -> Bool {
        let target = link.resolvingSymlinksInPath().standardizedFileURL.path
        return target == root.path || target.hasPrefix(root.path + "/")
    }
}
