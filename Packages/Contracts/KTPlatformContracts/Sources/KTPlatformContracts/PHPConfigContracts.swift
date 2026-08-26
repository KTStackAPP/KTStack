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

public enum PHPPoolProcessManager: String, Codable, Sendable, CaseIterable {
    case dynamic
    case `static`
    case ondemand
}

public struct PHPPoolSettings: Codable, Sendable, Equatable {
    public var processManager: PHPPoolProcessManager
    public var maxChildren: Int
    public var startServers: Int
    public var minSpareServers: Int
    public var maxSpareServers: Int
    public var processIdleTimeout: Int
    public var maxRequests: Int
    public var requestTerminateTimeout: Int

    public init(
        processManager: PHPPoolProcessManager,
        maxChildren: Int,
        startServers: Int,
        minSpareServers: Int,
        maxSpareServers: Int,
        processIdleTimeout: Int,
        maxRequests: Int,
        requestTerminateTimeout: Int
    ) {
        self.processManager = processManager
        self.maxChildren = maxChildren
        self.startServers = startServers
        self.minSpareServers = minSpareServers
        self.maxSpareServers = maxSpareServers
        self.processIdleTimeout = processIdleTimeout
        self.maxRequests = maxRequests
        self.requestTerminateTimeout = requestTerminateTimeout
    }

    // Giá trị writer render hôm nay; default output pool conf không đổi.
    public static let `default` = PHPPoolSettings(
        processManager: .dynamic,
        maxChildren: 5,
        startServers: 2,
        minSpareServers: 1,
        maxSpareServers: 3,
        processIdleTimeout: 10,
        maxRequests: 500,
        requestTerminateTimeout: 0
    )

    // Thêm field mới sau này: field thiếu trong file cũ về default thay vì hỏng decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PHPPoolSettings.default
        processManager = try c.decodeIfPresent(PHPPoolProcessManager.self, forKey: .processManager) ?? d.processManager
        maxChildren = try c.decodeIfPresent(Int.self, forKey: .maxChildren) ?? d.maxChildren
        startServers = try c.decodeIfPresent(Int.self, forKey: .startServers) ?? d.startServers
        minSpareServers = try c.decodeIfPresent(Int.self, forKey: .minSpareServers) ?? d.minSpareServers
        maxSpareServers = try c.decodeIfPresent(Int.self, forKey: .maxSpareServers) ?? d.maxSpareServers
        processIdleTimeout = try c.decodeIfPresent(Int.self, forKey: .processIdleTimeout) ?? d.processIdleTimeout
        maxRequests = try c.decodeIfPresent(Int.self, forKey: .maxRequests) ?? d.maxRequests
        requestTerminateTimeout = try c.decodeIfPresent(Int.self, forKey: .requestTerminateTimeout) ?? d.requestTerminateTimeout
    }

    // nil = hợp lệ; message ngắn dùng thẳng trên UI.
    public func validate() -> String? {
        if maxChildren < 1 { return "Max children must be at least 1." }
        if maxRequests < 0 { return "Max requests cannot be negative." }
        if requestTerminateTimeout < 0 { return "Request terminate timeout cannot be negative." }
        switch processManager {
        case .dynamic:
            guard minSpareServers >= 1 else { return "Min spare servers must be at least 1." }
            guard minSpareServers <= startServers else { return "Start servers must be at least min spare servers." }
            guard startServers <= maxSpareServers else { return "Max spare servers must be at least start servers." }
            guard maxSpareServers <= maxChildren else { return "Max spare servers cannot exceed max children." }
        case .ondemand:
            guard processIdleTimeout >= 1 else { return "Idle timeout must be at least 1 second." }
        case .static:
            break
        }
        return nil
    }
}

public enum PHPPoolSaveError: Error, Sendable, Equatable {
    case invalid(String)
    case rejected(String)
    case restartFailedReverted(String)
}

public protocol PHPPoolEditing: Sendable {
    var defaultPoolSettings: PHPPoolSettings { get }
    func poolSettings(phpVersion: String) throws -> PHPPoolSettings
    func savePoolSettings(phpVersion: String, _ settings: PHPPoolSettings) async throws
}
