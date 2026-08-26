import Foundation

public enum DatabaseEngine: String, Sendable, CaseIterable {
    case mysql, postgres, mongodb
}

// Mọi lần Database chạm binary/version của engine managed đi qua đây; conform trong KTStackKit.
// Plugin không thấy ServiceBinaryCatalog/ServiceVersionStore/MongoToolsCatalog: platform trả sẵn URL.
public protocol DatabaseToolsProviding: Sendable {
    func isInstalled(_ engine: DatabaseEngine) -> Bool
    func activeVersion(_ engine: DatabaseEngine) -> String?
    func binary(_ engine: DatabaseEngine, _ relPath: String) -> URL?
    func binary(_ engine: DatabaseEngine, _ relPath: String, version: String) -> URL?
    var mongoToolsInstalled: Bool { get }
    func mongoToolsBinary(_ relPath: String) -> URL?
}

// Trạng thái + lệnh service managed cho UI Database (reachability dot, nút Install/Start MongoDB).
// Không stream: reachability poll 5s, getter đồng bộ đủ.
public protocol DatabaseEngineManaging: AnyObject {
    @MainActor func isRunning(_ engine: DatabaseEngine) -> Bool
    @MainActor func install(_ engine: DatabaseEngine)
    @MainActor func toggle(_ engine: DatabaseEngine)
}
