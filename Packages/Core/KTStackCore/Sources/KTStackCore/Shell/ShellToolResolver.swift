import Foundation

public struct ShellToolResolver: Sendable {
    private let paths: AppSupportPaths

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
    }

    public func isToolEnabled(_ tool: String) -> Bool {
        guard let data = try? Data(contentsOf: paths.shellToolsConfigFile),
              let map = try? JSONDecoder().decode([String: Bool].self, from: data)
        else {
            return true
        }
        return map[tool] ?? true
    }

    public func resolve(tool: String, cwd: URL) -> URL? {
        guard isToolEnabled(tool) else { return nil }

        switch tool {
        case "kt":
            let shimKt = paths.shimBinDir.appendingPathComponent("kt")
            if FileManager.default.isExecutableFile(atPath: shimKt.path) { return shimKt }
            let appKt = URL(fileURLWithPath: "/Applications/KTStack.app/Contents/MacOS/kt")
            if FileManager.default.isExecutableFile(atPath: appKt.path) { return appKt }
            return nil
        case "php", "node":
            return resolveRuntime(tool, cwd: cwd)
        case "npm", "npx":
            return resolveNodeTool(tool, cwd: cwd)
        case "composer":
            guard FileManager.default.fileExists(atPath: paths.composerPhar.path) else { return nil }
            return resolveRuntime("php", cwd: cwd)
        case "wp":
            guard FileManager.default.fileExists(atPath: paths.wpCliPhar.path) else { return nil }
            return resolveRuntime("php", cwd: cwd)
        case "mysql", "mysqldump", "mysqladmin":
            return resolveMySQLTool(tool)
        case "psql", "pg_dump", "createdb", "dropdb":
            return resolveServiceTool(service: "postgres", binaryName: tool)
        case "redis-cli", "redis-benchmark":
            return resolveServiceTool(service: "redis", binaryName: tool)
        default:
            return nil
        }
    }

    public func isInstalled(_ tool: String) -> Bool {
        switch tool {
        case "kt":
            let shimKt = paths.shimBinDir.appendingPathComponent("kt")
            if FileManager.default.isExecutableFile(atPath: shimKt.path) { return true }
            let appKt = URL(fileURLWithPath: "/Applications/KTStack.app/Contents/MacOS/kt")
            if FileManager.default.isExecutableFile(atPath: appKt.path) { return true }
            return FileManager.default.isExecutableFile(atPath: "/usr/local/bin/kt")
        case "php":
            return !RuntimeCatalog(paths: paths).installedVersions(.php).isEmpty
        case "node", "npm", "npx":
            return !RuntimeCatalog(paths: paths).installedVersions(.node).isEmpty
        case "composer":
            return FileManager.default.fileExists(atPath: paths.composerPhar.path)
        case "wp":
            return FileManager.default.fileExists(atPath: paths.wpCliPhar.path)
        case "mysql", "mysqldump", "mysqladmin":
            return isServiceBinaryAvailable(service: "mysql", binaryName: tool)
                || isServiceBinaryAvailable(service: "mariadb", binaryName: tool)
        case "psql", "pg_dump", "createdb", "dropdb":
            return isServiceBinaryAvailable(service: "postgres", binaryName: tool)
        case "redis-cli", "redis-benchmark":
            return isServiceBinaryAvailable(service: "redis", binaryName: tool)
        default:
            return false
        }
    }

    private func resolveRuntime(_ lang: String, cwd: URL) -> URL? {
        guard let runtimeLang = RuntimeLanguage(rawValue: lang) else { return nil }
        let resolver = ShellRuntimeBinResolver(paths: paths)
        let installed = RuntimeCatalog(paths: paths).installedVersions(runtimeLang)
        guard let chosen = resolver.chooseVersion(runtimeLang, cwd: cwd, installed: installed),
              let bin = try? resolver.confinedBinary(runtimeLang, version: chosen),
              FileManager.default.isExecutableFile(atPath: bin.path)
        else {
            return nil
        }
        return bin
    }
    private func resolveNodeTool(_ tool: String, cwd: URL) -> URL? {
        guard let nodeBin = resolveRuntime("node", cwd: cwd) else { return nil }
        let bin = nodeBin.deletingLastPathComponent().appendingPathComponent(tool)
        guard FileManager.default.isExecutableFile(atPath: bin.path) else { return nil }
        return bin
    }


    private func resolveMySQLTool(_ tool: String) -> URL? {
        if let mysqlBin = resolveServiceTool(service: "mysql", binaryName: tool) {
            return mysqlBin
        }
        return resolveServiceTool(service: "mariadb", binaryName: tool)
    }

    private func resolveServiceTool(service: String, binaryName: String) -> URL? {
        let root = paths.runtimeLangRoot(service)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root.path), !entries.isEmpty else {
            return nil
        }
        let installed = entries.filter { version in
            let bin = paths.runtimeDir(service, version).appendingPathComponent("bin/\(binaryName)")
            return fm.isExecutableFile(atPath: bin.path)
        }
        guard !installed.isEmpty else { return nil }

        let activeVersion = readActiveVersion(for: service, installed: installed)
        let target = paths.runtimeDir(service, activeVersion).appendingPathComponent("bin/\(binaryName)")
        return fm.isExecutableFile(atPath: target.path) ? target : nil
    }

    private func isServiceBinaryAvailable(service: String, binaryName: String) -> Bool {
        let root = paths.runtimeLangRoot(service)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root.path) else { return false }
        return entries.contains { version in
            let bin = paths.runtimeDir(service, version).appendingPathComponent("bin/\(binaryName)")
            return fm.isExecutableFile(atPath: bin.path)
        }
    }

    private func readActiveVersion(for service: String, installed: [String]) -> String {
        let servicesFile = paths.config.appendingPathComponent("services.json")
        if let data = try? Data(contentsOf: servicesFile),
           let map = try? JSONDecoder().decode([String: String].self, from: data),
           let chosen = map[service],
           installed.contains(chosen) {
            return chosen
        }
        return installed.max { $0.compare($1, options: .numeric) == .orderedAscending } ?? installed[0]
    }
}
