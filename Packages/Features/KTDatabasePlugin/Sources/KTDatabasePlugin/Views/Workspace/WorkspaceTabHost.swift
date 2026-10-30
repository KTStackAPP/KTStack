import SwiftUI

private struct WorkspacePaneActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// false khi pane thuộc tab đang bị ẩn trong WorkspaceTabHost.
    var isWorkspacePaneActive: Bool {
        get { self[WorkspacePaneActiveKey.self] }
        set { self[WorkspacePaneActiveKey.self] = newValue }
    }
}

/// Giữ sống pane của từng tab, đổi tab chỉ ẩn/hiện thay vì dựng lại grid.
struct WorkspaceTabHost: NSViewControllerRepresentable {
    let tabs: [WorkspaceTabSession]
    let activeID: UUID
    let makePane: (WorkspaceTabSession) -> AnyView

    func makeNSViewController(context _: Context) -> WorkspaceTabHostController {
        WorkspaceTabHostController(limit: WorkspaceTabHostController.defaultLimit)
    }

    func updateNSViewController(_ controller: WorkspaceTabHostController, context _: Context) {
        let sessions = Dictionary(tabs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        controller.show(activeID: activeID, liveIDs: Set(sessions.keys)) { id in
            sessions[id].map(makePane)
        }
    }
}
