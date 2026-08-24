import Foundation
import KTPlatformContracts

struct FakeDatabaseTools: DatabaseToolsProviding {
    var installed: Set<DatabaseEngine> = []
    var versions: [DatabaseEngine: String] = [:]
    var binaries: [String: URL] = [:]
    var mongoInstalled = false
    var mongoBinaries: [String: URL] = [:]

    func isInstalled(_ engine: DatabaseEngine) -> Bool { installed.contains(engine) }
    func activeVersion(_ engine: DatabaseEngine) -> String? { versions[engine] }

    func binary(_ engine: DatabaseEngine, _ relPath: String) -> URL? {
        binaries["\(engine.rawValue):\(relPath)"] ?? binaries[relPath]
    }

    func binary(_ engine: DatabaseEngine, _ relPath: String, version _: String) -> URL? {
        binaries["\(engine.rawValue):\(relPath)"] ?? binaries[relPath]
    }

    var mongoToolsInstalled: Bool { mongoInstalled }
    func mongoToolsBinary(_ relPath: String) -> URL? { mongoBinaries[relPath] }
}
