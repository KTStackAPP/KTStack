import Foundation

@MainActor
final class WorkspaceSessionRegistry {
    static let shared = WorkspaceSessionRegistry()

    private struct Entry {
        weak var session: WorkspaceSession?
    }

    private var entries: [Entry] = []

    var sessions: [WorkspaceSession] {
        entries.compactMap(\.session)
    }

    var pendingChangeTotal: Int {
        sessions.reduce(0) { $0 + $1.pendingChangeTotal }
    }

    func register(_ session: WorkspaceSession) {
        entries.removeAll { $0.session == nil }
        entries.append(Entry(session: session))
    }
}
