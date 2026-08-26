import Foundation
import KTStackCore

// Capability màn Runtimes cần từ platform. Rule M10: contract = command (func) + state stream
// (AsyncStream snapshot); plugin wrap stream vào ObservableObject của nó, không thấy concrete manager.

public struct RuntimeDownloadProgress: Sendable, Equatable {
    public var version: String
    public var received: Int64
    public var total: Int64
    public var error: String?

    public init(version: String, received: Int64, total: Int64, error: String? = nil) {
        self.version = version
        self.received = received
        self.total = total
        self.error = error
    }

    public var fraction: Double {
        total > 0 ? min(1, Double(received) / Double(total)) : 0
    }
}

public struct RuntimeState: Sendable, Equatable {
    public var installed: [RuntimeLanguage: [String]]
    public var defaults: [RuntimeLanguage: String]
    public var downloads: [RuntimeLanguage: RuntimeDownloadProgress]

    public init(
        installed: [RuntimeLanguage: [String]] = [:],
        defaults: [RuntimeLanguage: String] = [:],
        downloads: [RuntimeLanguage: RuntimeDownloadProgress] = [:]
    ) {
        self.installed = installed
        self.defaults = defaults
        self.downloads = downloads
    }
}

public protocol RuntimeManaging: AnyObject {
    @MainActor var state: RuntimeState { get }
    @MainActor func states() -> AsyncStream<RuntimeState>
    @MainActor func availableReleases(_ lang: RuntimeLanguage) -> [RuntimeRelease]
    @MainActor func install(_ release: RuntimeRelease)
    @MainActor func cancel(_ lang: RuntimeLanguage)
    @MainActor func setGlobalDefault(_ lang: RuntimeLanguage, _ version: String)
    @MainActor func uninstall(_ lang: RuntimeLanguage, _ version: String)
    func isEndOfLife(_ lang: RuntimeLanguage, _ version: String) -> Bool
}

public struct WebEngineState: Sendable, Equatable {
    public var apacheVersion: String
    public var installed: Bool
    public var installing: Bool
    public var error: String?

    public init(apacheVersion: String, installed: Bool, installing: Bool, error: String? = nil) {
        self.apacheVersion = apacheVersion
        self.installed = installed
        self.installing = installing
        self.error = error
    }
}

public protocol WebEngineProvisioning: AnyObject {
    @MainActor var webEngineState: WebEngineState { get }
    @MainActor func webEngineStates() -> AsyncStream<WebEngineState>
    @MainActor func installApache()
}

// Projection theo capability (design mục 8): plugin không thấy Site model, chỉ domain của site đang
// dùng version PHP để dựng confirm uninstall.
public protocol PHPSiteRuntimeProviding: AnyObject {
    @MainActor func sitesUsingPHP(version: String) -> [String]
    @MainActor func reconcileAfterRuntimeChange()
}
