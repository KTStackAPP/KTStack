import AppKit
import Combine
import SwiftUI

@MainActor
final class SitesSplitController: NSSplitViewController {
    private let pane: SitesPaneModel
    private let inspectorItem: NSSplitViewItem
    private var cancellables: Set<AnyCancellable> = []
    private var collapseObservation: NSKeyValueObservation?

    init(pane: SitesPaneModel, list: AnyView, inspector: AnyView) {
        self.pane = pane

        let listItem = NSSplitViewItem(viewController: NSHostingController(rootView: list))
        listItem.minimumThickness = 420
        listItem.holdingPriority = .defaultLow

        inspectorItem = NSSplitViewItem(inspectorWithViewController: NSHostingController(rootView: inspector))
        inspectorItem.minimumThickness = 320
        inspectorItem.maximumThickness = 460
        inspectorItem.canCollapse = true
        inspectorItem.canCollapseFromWindowResize = true
        inspectorItem.holdingPriority = .defaultLow + 1

        super.init(nibName: nil, bundle: nil)

        addSplitViewItem(listItem)
        addSplitViewItem(inspectorItem)
        inspectorItem.isCollapsed = !pane.inspectorVisible

        bindModelToPane()
        bindPaneToModel()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func bindModelToPane() {
        pane.$inspectorVisible
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.setCollapsed(!visible) }
            .store(in: &cancellables)
    }

    // Kéo divider hoặc thu nhỏ cửa sổ cũng phải cập nhật lại model.
    private func bindPaneToModel() {
        collapseObservation = inspectorItem.observe(\.isCollapsed, options: [.new]) { [weak self] _, change in
            guard let collapsed = change.newValue else { return }
            Task { @MainActor in
                guard let self, self.pane.inspectorVisible == collapsed else { return }
                self.pane.inspectorVisible = !collapsed
            }
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard inspectorItem.isCollapsed != collapsed else { return }
        inspectorItem.animator().isCollapsed = collapsed
    }
}
