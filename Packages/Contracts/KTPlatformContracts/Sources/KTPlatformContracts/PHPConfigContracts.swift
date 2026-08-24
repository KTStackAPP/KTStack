import Foundation

// PHP config (ini, extension, xdebug) do platform giữ (fail-closed invariant, caller khác trong Kit).
// Orchestration pool (restart sau extension, reload + rollback sau ini) nằm platform, plugin chỉ UI state.

public struct PHPExtensionInfo: Sendable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let kind: String // PHPExtensionType.rawValue
    public let summary: String
    public let isBuiltIn: Bool

    public init(id: String, displayName: String, kind: String, summary: String, isBuiltIn: Bool) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.summary = summary
        self.isBuiltIn = isBuiltIn
    }
}

public enum PHPExtensionState: String, Sendable {
    case builtIn
    case installed
    case installedButFailedToLoad
    case available
    case unavailable
}

public struct PHPExtensionEntry: Sendable, Hashable, Identifiable {
    public let ext: PHPExtensionInfo
    public let state: PHPExtensionState

    public init(ext: PHPExtensionInfo, state: PHPExtensionState) {
        self.ext = ext
        self.state = state
    }

    public var id: String { ext.id }

    public static func == (lhs: PHPExtensionEntry, rhs: PHPExtensionEntry) -> Bool {
        lhs.ext == rhs.ext && lhs.state == rhs.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ext)
        hasher.combine(state)
    }
}

public struct PHPExtensionInstallOutcome: Sendable, Equatable {
    public let loaded: Bool
    public let warning: String?

    public init(loaded: Bool, warning: String?) {
        self.loaded = loaded
        self.warning = warning
    }
}

public protocol PHPExtensionManaging: Sendable {
    func extensions(phpVersion: String) async -> [PHPExtensionEntry]
    func installExtension(
        _ id: String,
        phpVersion: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> PHPExtensionInstallOutcome
    func uninstallExtension(_ id: String, phpVersion: String) async throws
    var xdebugClientPort: Int { get }
    func isXdebugSupported(phpVersion: String) -> Bool
    func isXdebugEnabled(phpVersion: String) -> Bool
    func setXdebug(_ enabled: Bool, phpVersion: String) async throws
}

public enum PHPIniSaveError: Error, Sendable, Equatable {
    case syntax(String)
    case reloadFailedReverted(String)
}

public protocol PHPIniEditing: Sendable {
    var defaultTemplate: String { get }
    func readIni(phpVersion: String) throws -> String
    func saveIni(phpVersion: String, contents: String) async throws
}
