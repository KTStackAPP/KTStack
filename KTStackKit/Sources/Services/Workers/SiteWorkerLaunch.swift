import Foundation
import KTStackCore

struct SiteWorkerLaunch: Sendable {
    static let systemPath = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    let paths: AppSupportPaths
    let supervisorExecutable: URL
    let parentPID: pid_t

    func label(site: Site, worker: SiteWorker) -> String {
        paths.siteWorkerLabel(siteID: site.id.uuidString, workerID: worker.id.uuidString)
    }

    func spec(site: Site, worker: SiteWorker, phpVersion: String) -> LaunchAgentSpec? {
        guard let words = SiteWorkerCommand.arguments(worker.command) else { return nil }
        let program = resolvedProgram(words, phpVersion: phpVersion)
        let label = self.label(site: site, worker: worker)
        let log = paths.siteWorkerLog(site.domain, worker: worker.name).path
        let supervised = WorkerSupervisor.commandLine(
            parentPID: parentPID,
            statusURL: paths.siteWorkerStatus(label),
            executable: program.executable,
            arguments: program.arguments
        )
        return LaunchAgentSpec(
            label: label,
            programArguments: [supervisorExecutable.path] + supervised,
            workingDirectory: site.path,
            environment: environment(site: site, phpVersion: phpVersion),
            stdoutPath: log,
            stderrPath: log,
            keepAliveOnCrash: true,
            runAtLoad: true
        )
    }

    func resolvedProgram(_ words: [String], phpVersion: String) -> (executable: String, arguments: [String]) {
        let rest = Array(words.dropFirst())
        guard words.first == "php" else { return (words[0], rest) }
        let ini = paths.phpIni(version: phpVersion)
        let iniArguments = FileManager.default.fileExists(atPath: ini.path) ? ["-c", ini.path] : []
        return (paths.phpBinary(version: phpVersion).path, iniArguments + rest)
    }

    func environment(site: Site, phpVersion: String) -> [String: String] {
        var env: [String: String] = [:]
        for (key, value) in SiteEnvVars.renderable(site.envVars) {
            env[key] = value
        }
        let phpBin = paths.runtimeBin("php", phpVersion).path
        env["PATH"] = [phpBin, paths.shimBinDir.path, Self.systemPath].joined(separator: ":")
        env["HOME"] = NSHomeDirectory()
        env["PHPRC"] = paths.phpIniDir(version: phpVersion).path
        let scanDir = paths.phpExtConfDir(version: phpVersion)
        if FileManager.default.fileExists(atPath: scanDir.path) {
            env["PHP_INI_SCAN_DIR"] = scanDir.path
        }
        for (key, value) in ImageMagickEnvironment.variables(modulesDir: paths.phpModulesDir(version: phpVersion)) {
            env[key] = value
        }
        return env
    }
}
