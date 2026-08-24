import Foundation
import KTPlatformContracts

@MainActor
final class PHPExtensionsModel: ObservableObject {
    let version: String
    @Published private(set) var rows: [PHPExtensionEntry] = []
    @Published private(set) var busy: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var errors: [String: String] = [:]

    private let phpConfig: any PHPExtensionManaging

    init(version: String, phpConfig: any PHPExtensionManaging) {
        self.version = version
        self.phpConfig = phpConfig
    }

    func refresh() async {
        rows = await phpConfig.extensions(phpVersion: version)
    }

    func install(_ extID: String) async {
        guard !busy.contains(extID) else { return }
        begin(extID)
        do {
            let outcome = try await phpConfig.installExtension(extID, phpVersion: version) { [weak self] fraction in
                Task { @MainActor in self?.progress[extID] = fraction }
            }
            await refresh()
            if !outcome.loaded {
                errors[extID] = outcome.warning ?? "Installed but the extension failed to load."
            }
        } catch {
            errors[extID] = error.localizedDescription
        }
        end(extID)
    }

    func uninstall(_ extID: String) async {
        guard !busy.contains(extID) else { return }
        begin(extID)
        do {
            try await phpConfig.uninstallExtension(extID, phpVersion: version)
            await refresh()
        } catch {
            errors[extID] = error.localizedDescription
        }
        end(extID)
    }

    private func begin(_ extID: String) {
        busy.insert(extID); errors[extID] = nil; progress[extID] = nil
    }

    private func end(_ extID: String) {
        busy.remove(extID); progress[extID] = nil
    }
}
