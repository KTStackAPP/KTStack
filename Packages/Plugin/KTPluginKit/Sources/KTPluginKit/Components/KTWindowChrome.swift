import AppKit
import SwiftUI

public struct KTWindowChrome: NSViewRepresentable {
    public init() {}

    public func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in Self.configure(view?.window) }
        return view
    }

    public func updateNSView(_ view: NSView, context _: Context) {
        DispatchQueue.main.async { [weak view] in Self.configure(view?.window) }
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
    }
}
