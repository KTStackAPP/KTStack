import Foundation
import KTStackCore
@testable import KTStackKit

final class FakeLaunchAgentManager: LaunchAgentManaging, @unchecked Sendable {
    enum Call: Equatable {
        case writePlist(String)
        case bootstrap(String)
        case kickstart(String)
        case bootout(String)
    }

    enum Operation: Hashable {
        case bootstrap, kickstart, bootout
    }

    private let lock = NSLock()
    private let paths: AppSupportPaths
    private var loaded: Set<String>
    private var recorded: [Call] = []
    private var failures: [Operation: Error] = [:]

    init(paths: AppSupportPaths, loaded: Set<String> = []) {
        self.paths = paths
        self.loaded = loaded
    }

    var calls: [Call] {
        locked { recorded }
    }

    var loadedLabels: Set<String> {
        locked { loaded }
    }

    func fail(_ operation: Operation, with error: Error) {
        locked { failures[operation] = error }
    }

    func markLoaded(_ label: String) {
        locked { _ = loaded.insert(label) }
    }

    @discardableResult
    func writePlist(for spec: LaunchAgentSpec) throws -> URL {
        locked { recorded.append(.writePlist(spec.label)) }
        return paths.launchAgentPlist(spec.label)
    }

    func bootstrap(_ spec: LaunchAgentSpec) throws {
        try perform(.bootstrap, call: .bootstrap(spec.label)) { loaded.insert(spec.label) }
    }

    func kickstart(_ label: String) throws {
        try perform(.kickstart, call: .kickstart(label)) {}
    }

    func bootout(_ label: String) throws {
        try perform(.bootout, call: .bootout(label)) { loaded.remove(label) }
    }

    func isLoaded(_ label: String) -> Bool {
        locked { loaded.contains(label) }
    }

    func isLoadedNow(_ label: String) -> Bool {
        isLoaded(label)
    }

    func diagnostics() -> ServiceDiagnostics {
        ServiceDiagnostics(paths: paths)
    }

    private func perform(_ operation: Operation, call: Call, mutation: () -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(call)
        if let error = failures[operation] { throw error }
        mutation()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
