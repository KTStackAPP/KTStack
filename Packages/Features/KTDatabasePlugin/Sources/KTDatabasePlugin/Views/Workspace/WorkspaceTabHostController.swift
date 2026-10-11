import AppKit
import SwiftUI

@MainActor
final class WorkspaceTabHostController: NSViewController {
    static let defaultLimit = 8

    private var hosts: [UUID: NSHostingController<AnyView>] = [:]
    private var panes: [UUID: AnyView] = [:]
    private var cache: WorkspacePaneCache
    private var activeID: UUID?

    init(limit: Int) {
        cache = WorkspacePaneCache(limit: limit)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func loadView() {
        view = NSView()
    }

    func show(activeID newID: UUID, liveIDs: Set<UUID>, makePane: (UUID) -> AnyView?) {
        for id in cache.retain(liveIDs) {
            drop(id)
        }

        if hosts[newID] == nil {
            guard let pane = makePane(newID) else { return }
            install(pane, for: newID)
        }

        let previousID = activeID
        guard previousID != newID else { return }
        activeID = newID

        if let previousID, let previous = hosts[previousID] {
            resignFocus(from: previous.view)
            previous.view.isHidden = true
            setActive(false, for: previousID)
        }
        hosts[newID]?.view.isHidden = false
        setActive(true, for: newID)

        for id in cache.touch(newID) {
            drop(id)
        }
    }

    private func install(_ pane: AnyView, for id: UUID) {
        let host = NSHostingController(rootView: Self.root(pane, active: false))
        host.sizingOptions = []
        host.view.isHidden = true
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosts[id] = host
        panes[id] = pane
    }

    private func setActive(_ active: Bool, for id: UUID) {
        guard let host = hosts[id], let pane = panes[id] else { return }
        host.rootView = Self.root(pane, active: active)
    }

    private func drop(_ id: UUID) {
        guard let host = hosts.removeValue(forKey: id) else { return }
        panes[id] = nil
        resignFocus(from: host.view)
        host.view.removeFromSuperview()
        host.removeFromParent()
        if activeID == id {
            activeID = nil
        }
    }

    /// Không để first responder nằm trong pane đã ẩn, phím gõ sẽ đi vào tab không nhìn thấy.
    private func resignFocus(from hostView: NSView) {
        guard let window = hostView.window,
              let responder = window.firstResponder as? NSView,
              responder.isDescendant(of: hostView) else { return }
        window.makeFirstResponder(nil)
    }

    private static func root(_ pane: AnyView, active: Bool) -> AnyView {
        AnyView(pane.environment(\.isWorkspacePaneActive, active))
    }
}
