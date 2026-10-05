import Foundation
import KTStackCore

@MainActor
final class SiteWorkersModel: ObservableObject {
    struct Draft: Equatable {
        var editing: UUID?
        var name: String
        var command: String
    }

    @Published var draft: Draft?
    @Published var error: String?

    private let saveFn: ([SiteWorker]) throws -> Void

    init(save: @escaping ([SiteWorker]) throws -> Void) {
        saveFn = save
    }

    func presets(isLaravel: Bool, current: [SiteWorker]) -> [SiteWorkerPreset] {
        guard isLaravel else { return [] }
        let commands = Set(current.map(\.command))
        return SiteWorkerPreset.allCases.filter { !commands.contains($0.command) }
    }

    func add(_ preset: SiteWorkerPreset, current: [SiteWorker]) {
        let worker = SiteWorker(name: SiteWorkers.suggestedName(preset.name, existing: current), command: preset.command)
        save(current + [worker])
    }

    func beginAdd(current: [SiteWorker]) {
        error = nil
        draft = Draft(editing: nil, name: SiteWorkers.suggestedName("worker", existing: current), command: "php artisan ")
    }

    func beginEdit(_ worker: SiteWorker) {
        error = nil
        draft = Draft(editing: worker.id, name: worker.name, command: worker.command)
    }

    func cancelDraft() {
        draft = nil
        error = nil
    }

    func commitDraft(current: [SiteWorker]) {
        guard let draft else { return }
        let name = draft.name.trimmingCharacters(in: .whitespaces).lowercased()
        let command = draft.command.trimmingCharacters(in: .whitespaces)
        var next = current
        if let id = draft.editing, let index = next.firstIndex(where: { $0.id == id }) {
            next[index].name = name
            next[index].command = command
        } else {
            next.append(SiteWorker(name: name, command: command))
        }
        if save(next) { self.draft = nil }
    }

    func remove(_ worker: SiteWorker, current: [SiteWorker]) {
        save(current.filter { $0.id != worker.id })
    }

    @discardableResult
    private func save(_ workers: [SiteWorker]) -> Bool {
        if let invalid = SiteWorkers.validate(workers) {
            error = invalid.errorDescription
            return false
        }
        do {
            try saveFn(workers)
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
