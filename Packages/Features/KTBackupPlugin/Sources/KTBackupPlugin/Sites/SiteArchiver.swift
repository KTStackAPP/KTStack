import Foundation

struct SiteArchiver {
    let matcher: ExcludeMatcher

    static func archiveName(for site: BackupSiteFolder) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let slug = String(site.name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return "\(slug)-\(site.id.uuidString.prefix(8).lowercased()).tar.gz"
    }

    func archive(_ site: BackupSiteFolder, to destination: URL) throws {
        let root = site.root.resolvingSymlinksInPath().standardizedFileURL
        let entries = try SiteFileCollector(matcher: matcher).collect(root: root)
        let listFile = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).list")
        defer { try? FileManager.default.removeItem(at: listFile) }
        var list = Data()
        for entry in entries {
            list.append(Data(entry.utf8))
            list.append(0)
        }
        try list.write(to: listFile)
        try ArchiveTool.run(
            ArchiveTool.tarPath,
            ["-czf", destination.path, "--no-recursion", "--null", "-T", listFile.path],
            currentDirectory: root
        )
    }
}
