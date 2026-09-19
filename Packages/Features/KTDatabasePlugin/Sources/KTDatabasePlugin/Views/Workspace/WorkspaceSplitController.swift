import AppKit
import Combine
import SwiftUI

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
                .environmentObject(model.databaseVM)
                .environmentObject(model.documentVM)
                .environmentObject(model.connectionStore)
        )
        sidebarPane = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarPane.minimumThickness = 248
        sidebarPane.maximumThickness = 380
        sidebarPane.canCollapse = false
        sidebarPane.holdingPriority = .defaultLow + 1

        let content = NSHostingController(
            rootView: WorkspaceContentPane(
                model: model, vm: vm, workspace: workspace, sectionState: model.sectionState
            )
            .environmentObject(model.databaseVM)
            .environmentObject(model.documentVM)
            .environmentObject(model.connectionStore)
        )
        let contentPane = NSSplitViewItem(viewController: content)
        contentPane.minimumThickness = 480
        contentPane.holdingPriority = .defaultLow

        let inspector = NSHostingController(
            rootView: WorkspaceInspectorPane(workspace: workspace)
        )
        inspectorPane = NSSplitViewItem(inspectorWithViewController: inspector)
        inspectorPane.minimumThickness = 250
        inspectorPane.maximumThickness = 460
        inspectorPane.canCollapse = false
        inspectorPane.holdingPriority = .defaultLow + 1

        super.init(nibName: nil, bundle: nil)

        addSplitViewItem(sidebarPane)
        addSplitViewItem(contentPane)
        addSplitViewItem(inspectorPane)

        sidebarPane.isCollapsed = !workspace.sidebarVisible
        inspectorPane.isCollapsed = !workspace.inspectorVisible

        bindStoreToPanes()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        sidebarPane.isCollapsed = !workspace.sidebarVisible
        inspectorPane.isCollapsed = !workspace.inspectorVisible
    }

    private func bindStoreToPanes() {
        workspace.$sidebarVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.setCollapsed(self?.sidebarPane, collapsed: !visible) }
            .store(in: &cancellables)
        workspace.$inspectorVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.setCollapsed(self?.inspectorPane, collapsed: !visible) }
            .store(in: &cancellables)
    }

    private func setCollapsed(_ item: NSSplitViewItem?, collapsed: Bool) {
        guard let item, item.isCollapsed != collapsed else { return }
        item.animator().isCollapsed = collapsed
    }
}
