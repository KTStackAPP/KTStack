import AppKit
import Combine
import SwiftUI

// NSSplitView thường: NSSplitViewController trên macOS 26 tự gắn titlebar pocket lên mép trên.
@MainActor
final class SitesSplitController: NSViewController, NSSplitViewDelegate {
    private enum Width {
        static let listMin: CGFloat = 420
        static let inspectorMin: CGFloat = 320
        static let inspectorMax: CGFloat = 460
        static let inspectorDefault: CGFloat = 360
    }

    private let pane: SitesPaneModel
    private let splitView = NSSplitView()
    private let listView: NSView
    private let inspectorView: NSView
    private var inspectorWidth = Width.inspectorDefault
    private var collapsedByResize = false
    private var didPlaceDivider = false
    private var isAdjusting = false
    private var cancellables: Set<AnyCancellable> = []

    init(pane: SitesPaneModel, list: AnyView, inspector: AnyView) {
        self.pane = pane
        listView = NSHostingView(rootView: list)
        inspectorView = NSHostingView(rootView: inspector)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func loadView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addArrangedSubview(listView)
        splitView.addArrangedSubview(inspectorView)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow + 1, forSubviewAt: 1)
        inspectorView.isHidden = !pane.inspectorVisible
        view = splitView
        bindModelToSplit()
    }

    private var inspectorShown: Bool {
        !inspectorView.isHidden && !splitView.isSubviewCollapsed(inspectorView)
    }

    private var inspectorFits: Bool {
        splitView.bounds.width >= Width.listMin + splitView.dividerThickness + Width.inspectorMin
    }

    private func bindModelToSplit() {
        pane.$inspectorVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self else { return }
                self.collapsedByResize = false
                self.apply(visible: visible)
            }
            .store(in: &cancellables)
    }

    private func apply(visible: Bool) {
        guard inspectorShown != visible else { return }
        adjusting {
            inspectorView.isHidden = !visible
            splitView.adjustSubviews()
            if visible { placeDivider() }
        }
    }

    private func placeDivider() {
        let position = splitView.bounds.width - splitView.dividerThickness - inspectorWidth
        splitView.setPosition(max(position, Width.listMin), ofDividerAt: 0)
    }

    private func adjusting(_ body: () -> Void) {
        isAdjusting = true
        body()
        isAdjusting = false
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate _: CGFloat, ofSubviewAt _: Int) -> CGFloat {
        max(Width.listMin, splitView.bounds.width - splitView.dividerThickness - Width.inspectorMax)
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate _: CGFloat, ofSubviewAt _: Int) -> CGFloat {
        splitView.bounds.width - splitView.dividerThickness - Width.inspectorMin
    }

    func splitView(_: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        subview === inspectorView
    }

    // Kéo divider hoặc đổi cỡ cửa sổ cũng phải cập nhật lại model.
    func splitViewDidResizeSubviews(_: Notification) {
        guard !isAdjusting, splitView.bounds.width > 0 else { return }
        if !didPlaceDivider {
            didPlaceDivider = true
            if inspectorShown { adjusting { placeDivider() } }
            return
        }
        if inspectorShown {
            inspectorWidth = min(max(inspectorView.frame.width, Width.inspectorMin), Width.inspectorMax)
            if !inspectorFits {
                pane.inspectorVisible = false
                collapsedByResize = true
            }
        } else if collapsedByResize {
            if inspectorFits { pane.inspectorVisible = true }
        } else if pane.inspectorVisible {
            pane.inspectorVisible = false
        }
    }
}
