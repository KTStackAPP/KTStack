import AppKit
import Combine
import SwiftUI

/// Khung cửa sổ workspace: NSSplitViewController ba pane (sidebar material / content / inspector).
/// Collapse đồng bộ hai chiều với hai cờ frozen của WorkspaceStore; divider tự lưu qua autosave.
@MainActor
final class WorkspaceSplitController: NSSplitViewController {
    private let workspace: WorkspaceStore
    private let sidebarPane: NSSplitViewItem
    private let inspectorPane: NSSplitViewItem
    private var cancellables: Set<AnyCancellable> = []

    init(model: WorkspaceRootModel) {
        workspace = model.session.store
        let vm = model.session.shell

        let sidebar = NSHostingController(
            rootView: WorkspaceSidebarPane(model: model, vm: vm, workspace: workspace)
        )
        sidebarPane = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarPane.minimumThickness = 248
        sidebarPane.maximumThickness = 380
        sidebarPane.canCollapse = true

        let content = NSHostingController(
            rootView: WorkspaceContentPane(
                model: model, vm: vm, workspace: workspace, sectionState: model.sectionState
            )
        )
        let contentPane = NSSplitViewItem(viewController: content)
        contentPane.minimumThickness = 480

        let inspector = NSHostingController(
            rootView: WorkspaceInspectorPane(workspace: workspace)
        )
        inspectorPane = NSSplitViewItem(inspectorWithViewController: inspector)
        inspectorPane.minimumThickness = 250
        inspectorPane.maximumThickness = 460
        inspectorPane.canCollapse = true

        super.init(nibName: nil, bundle: nil)

        addSplitViewItem(sidebarPane)
        addSplitViewItem(contentPane)
        addSplitViewItem(inspectorPane)

        let isConnected: Bool
        if case .connected = vm.connectionState { isConnected = true } else { isConnected = false }
        sidebarPane.isCollapsed = !isConnected || !workspace.sidebarVisible
        inspectorPane.isCollapsed = !workspace.inspectorVisible

        bindStoreToPanes(vm: vm)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.autosaveName = "KTStackDatabaseSplit"
    }

    private func bindStoreToPanes(vm: DatabaseV2ViewModel) {
        workspace.$sidebarVisible
            .sink { [weak self] visible in self?.setCollapsed(self?.sidebarPane, collapsed: !visible) }
            .store(in: &cancellables)
        workspace.$inspectorVisible
            .sink { [weak self] visible in self?.setCollapsed(self?.inspectorPane, collapsed: !visible) }
            .store(in: &cancellables)
        vm.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let isConnected: Bool
                if case .connected = state { isConnected = true } else { isConnected = false }
                if !isConnected {
                    self.setCollapsed(self.sidebarPane, collapsed: true)
                } else if self.workspace.sidebarVisible {
                    self.setCollapsed(self.sidebarPane, collapsed: false)
                }
            }
            .store(in: &cancellables)
    }
    private func setCollapsed(_ item: NSSplitViewItem?, collapsed: Bool) {
        guard let item, item.isCollapsed != collapsed else { return }
        item.animator().isCollapsed = collapsed
    }

    // Pane → store: kéo divider để collapse ghi lại vào hai key frozen.
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        let sidebarVisible = !sidebarPane.isCollapsed
        let inspectorVisible = !inspectorPane.isCollapsed
        if workspace.sidebarVisible != sidebarVisible { workspace.sidebarVisible = sidebarVisible }
        if workspace.inspectorVisible != inspectorVisible { workspace.inspectorVisible = inspectorVisible }
    }
}
