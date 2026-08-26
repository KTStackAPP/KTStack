import AppKit
import Combine
import KTPluginKit
import SwiftUI

struct KTWindowModals: View {
    @EnvironmentObject private var modals: KTModalPresenter

    var body: some View {
        ZStack {
            if let modal = modals.modal {
                modal.content()
                    .id(modal.id)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: modals.modal?.id)
    }
}

final class KTKeyableModalWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class KTModalHostController {
    private let modals: KTModalPresenter
    private weak var parentWindow: NSWindow?
    private let window: KTKeyableModalWindow
    private var cancellables: Set<AnyCancellable> = []
    private var isShown = false

    init(parent: NSWindow, modals: KTModalPresenter) {
        self.modals = modals
        parentWindow = parent

        window = KTKeyableModalWindow(
            contentRect: parent.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = NSHostingView(rootView: AnyView(KTWindowModals().environmentObject(modals)))

        observe()
        syncPresentation()
    }

    private func observe() {
        modals.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.syncPresentation() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: parentWindow)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: parentWindow))
            .sink { [weak self] _ in
                guard let self, isShown else { return }
                syncFrame()
            }
            .store(in: &cancellables)
    }

    private func syncPresentation() {
        modals.modal != nil ? show() : hide()
    }

    private func syncFrame() {
        guard let parentWindow else { return }
        window.setFrame(parentWindow.frame, display: true)
    }

    private func show() {
        guard !isShown, let parentWindow else { return }
        isShown = true
        syncFrame()
        if window.parent == nil { parentWindow.addChildWindow(window, ordered: .above) }
        syncFrame()
        window.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self, !self.isShown, self.modals.modal == nil else { return }
            parentWindow?.removeChildWindow(window)
            window.orderOut(nil)
            parentWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
