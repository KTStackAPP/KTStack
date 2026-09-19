import AppKit

final class TabbingWindow: NSWindow {
    var onNewTab: (() -> Void)?
    override func newWindowForTab(_: Any?) { onNewTab?() }
}
