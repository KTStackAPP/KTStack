// Capability PHP runtime mà feature plugin (Dumps) cần; platform conform trong KTStackKit.
// File ops nonisolated để quit path (block main thread) gọi được mà không hop MainActor.
public protocol PHPRuntimeConfiguring: AnyObject, Sendable {
    var installedPHPVersions: [String] { get }
    func setAutoPrepend(file: String, version: String) throws
    func removeAutoPrepend(file: String, version: String) throws
    func isAutoPrependSet(file: String, version: String) -> Bool
    @MainActor func reloadPHPPool(version: String) async throws
}
