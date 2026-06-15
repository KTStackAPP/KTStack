import Foundation


public struct PHPExtensionInstaller: Sendable {
    public enum InstallResult: Sendable, Equatable {
        case installed
       
        case installedButFailedToLoad(warning: String?)
    }

    public enum InstallError: LocalizedError {
        case noReleaseAvailable(ext: String, phpVersion: String)
        public var errorDescription: String? {
            switch self {
            case .noReleaseAvailable(let ext, let v):
                return "No \(ext) build is available for PHP \(v)."
            }
        }
    }

    private let paths: AppSupportPaths
    private let catalog: PHPExtensionCatalog
    public init(paths: AppSupportPaths) {
        self.paths = paths
        self.catalog = PHPExtensionCatalog(paths: paths)
    }

    // MARK: - Ini generation

   
    public func iniContent(forExtID extID: String, phpVersion: String) -> String {
        let directive = PHPExtensionCatalog.descriptor(extID)?.loadDirective ?? .module
        switch directive {
        case .module:
            return "extension=\(extID).so\n"
        case .zendExtension:
            let abs = soURL(extID, phpVersion).path
            return "zend_extension=\(abs)\n"
        }
    }

    public func extensionIniURL(extID: String, phpVersion: String) -> URL {
        paths.phpExtConfDir(version: phpVersion).appendingPathComponent("20-\(extID).ini")
    }
   
    public func extensionDirIniURL(phpVersion: String) -> URL {
        paths.phpExtConfDir(version: phpVersion).appendingPathComponent("00-extension-dir.ini")
    }

    // MARK: - File operations

    public func writeExtensionDirIni(phpVersion: String) throws {
        let dir = paths.phpExtConfDir(version: phpVersion)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let body = "extension_dir = \"\(paths.phpModulesDir(version: phpVersion).path)\"\n"
        try body.write(to: extensionDirIniURL(phpVersion: phpVersion), atomically: true, encoding: .utf8)
    }

    public func placeSharedObject(from local: URL, extID: String, phpVersion: String) throws {
        let modules = paths.phpModulesDir(version: phpVersion)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let dest = soURL(extID, phpVersion)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: local, to: dest)
    }

    
    public func finishInstall(extID: String, phpVersion: String) throws {
        try writeExtensionDirIni(phpVersion: phpVersion)
        try iniContent(forExtID: extID, phpVersion: phpVersion)
            .write(to: extensionIniURL(extID: extID, phpVersion: phpVersion), atomically: true, encoding: .utf8)
    }

    // MARK: - Lifecycle

    @discardableResult
    public func install(_ extID: String, phpVersion: String,
                        onProgress: @escaping @Sendable (RuntimeDownloader.Progress) -> Void = { _ in })
        async throws -> InstallResult {
        guard let release = catalog.release(extID, phpVersion: phpVersion) else {
            throw InstallError.noReleaseAvailable(ext: extID, phpVersion: phpVersion)
        }
        try await RuntimeDownloader(paths: paths).installSharedObject(
            url: release.url, sha256: release.sha256, soName: "\(extID).so",
            into: paths.phpModulesDir(version: phpVersion), onProgress: onProgress)
        try finishInstall(extID: extID, phpVersion: phpVersion)
        PHPModules.invalidate(version: phpVersion)   // status re-reads after the change (L2)

        let (loaded, warning) = verifyLoad(extID: extID, phpVersion: phpVersion)
        return loaded ? .installed : .installedButFailedToLoad(warning: warning)
    }

  
    public func uninstall(_ extID: String, phpVersion: String) throws {
        let fm = FileManager.default
        for url in [extensionIniURL(extID: extID, phpVersion: phpVersion), soURL(extID, phpVersion)]
        where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        PHPModules.invalidate(version: phpVersion)
    }

    // MARK: - Load verification (silent-fail detection, red-team H2)

    public func verifyLoad(extID: String, phpVersion: String) -> (loaded: Bool, warning: String?) {
        let php = paths.phpBinary(version: phpVersion)
        guard FileManager.default.isExecutableFile(atPath: php.path) else { return (false, nil) }

        let modules = paths.phpModulesDir(version: phpVersion)
        let directive = PHPExtensionCatalog.descriptor(extID)?.loadDirective ?? .module
        var args = ["-d", "extension_dir=\(modules.path)"]
        switch directive {
        case .module:        args += ["-d", "extension=\(extID).so"]
        case .zendExtension: args += ["-d", "zend_extension=\(soURL(extID, phpVersion).path)"]
        }
        args.append("-m")

        let proc = Process()
        proc.executableURL = php
        proc.arguments = args
        let out = Pipe(); let err = Pipe()
        proc.standardOutput = out; proc.standardError = err
        do { try proc.run() } catch { return (false, error.localizedDescription) }
        let outText = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errText = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        proc.waitUntilExit()

      
        let modulesList = outText.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let loaded = proc.terminationStatus == 0 && modulesList.contains(extID.lowercased())
      
        let warning = (errText + "\n" + outText).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.range(of: "Unable to load", options: .caseInsensitive) != nil
                  || $0.range(of: "Failed loading", options: .caseInsensitive) != nil }
        return (loaded, loaded ? nil : warning)
    }

    private func soURL(_ extID: String, _ phpVersion: String) -> URL {
        paths.phpModulesDir(version: phpVersion).appendingPathComponent("\(extID).so")
    }
}
