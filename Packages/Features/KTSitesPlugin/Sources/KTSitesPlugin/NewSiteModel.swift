import AppKit
import Foundation
import KTPlatformContracts

@MainActor
final class NewSiteModel: ObservableObject {
    @Published private(set) var events: [InstallEvent] = []
    @Published private(set) var installing = false
    @Published private(set) var finished = false
    @Published var error: String?

    private let provisioning: any SiteProvisioning
    private let catalog: any SiteCatalogManaging
    private let open: (URL) -> Void
    private var task: Task<Void, Never>?

    init(
        provisioning: any SiteProvisioning,
        catalog: any SiteCatalogManaging,
        open: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.provisioning = provisioning
        self.catalog = catalog
        self.open = open
    }

    @discardableResult
    func install(request: NewSiteRequest, openOnFinish: Bool, enableHTTPS: Bool = true) -> Task<Void, Never> {
        guard !installing else { return Task {} }
        do {
            try catalog.validateDomain(request.domain, excluding: nil)
        } catch {
            self.error = error.localizedDescription
            return Task {}
        }
        installing = true
        error = nil
        events = []

        let newTask = Task {
            do {
                let site = try await provisioning.install(request, enableHTTPS: enableHTTPS) { event in
                    Task { @MainActor in self.events.append(event) }
                }
                finished = true
                if openOnFinish {
                    let scheme = enableHTTPS ? "https" : "http"
                    if let url = URL(string: "\(scheme)://\(site.domain)/") { open(url) }
                }
            } catch is CancellationError {
                error = "Cancelled."
            } catch {
                self.error = error.localizedDescription
            }
            installing = false
        }
        task = newTask
        return newTask
    }

    @discardableResult
    func importExisting(
        folder: URL,
        domain: String,
        phpVersion: String,
        createDatabase: Bool,
        enableHTTPS: Bool,
        openOnFinish: Bool = true
    ) -> Task<Void, Never> {
        guard !installing else { return Task {} }
        do {
            try catalog.validateDomain(domain, excluding: nil)
        } catch {
            self.error = error.localizedDescription
            return Task {}
        }
        installing = true
        error = nil
        events = []

        let newTask = Task {
            do {
                let site = try await provisioning.importFolder(
                    folder,
                    domain: domain,
                    phpVersion: phpVersion,
                    createDatabase: createDatabase,
                    enableHTTPS: enableHTTPS
                )
                finished = true
                if openOnFinish {
                    let scheme = enableHTTPS ? "https" : "http"
                    if let url = URL(string: "\(scheme)://\(site.domain)/") { open(url) }
                }
            } catch is CancellationError {
                error = "Cancelled."
            } catch {
                self.error = error.localizedDescription
            }
            installing = false
        }
        task = newTask
        return newTask
    }

    @discardableResult
    func addProxy(
        name: String,
        domain: String,
        target: String,
        enableHTTPS: Bool,
        openOnFinish: Bool = true
    ) -> Task<Void, Never> {
        guard !installing else { return Task {} }
        do {
            try catalog.validateDomain(domain, excluding: nil)
        } catch {
            self.error = error.localizedDescription
            return Task {}
        }
        installing = true
        error = nil
        events = []

        let newTask = Task {
            do {
                let site = try await provisioning.addProxySite(
                    name: name, domain: domain, target: target, enableHTTPS: enableHTTPS
                )
                finished = true
                if openOnFinish {
                    let scheme = enableHTTPS ? "https" : "http"
                    if let url = URL(string: "\(scheme)://\(site.domain)/") { open(url) }
                }
            } catch is CancellationError {
                error = "Cancelled."
            } catch {
                self.error = error.localizedDescription
            }
            installing = false
        }
        task = newTask
        return newTask
    }

    func cancel() {
        task?.cancel()
    }

    func reset() {
        error = nil
        events = []
    }
}
