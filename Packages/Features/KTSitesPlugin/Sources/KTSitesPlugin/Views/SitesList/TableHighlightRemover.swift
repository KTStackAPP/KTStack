import AppKit
import SwiftUI

// Tắt highlight hệ thống của bảng chứa row; row tự vẽ nền chọn.
struct TableHighlightRemover: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView { Probe() }
    func updateNSView(_: NSView, context _: Context) {}

    private final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            var view = superview
            while let current = view, !(current is NSTableView) { view = current.superview }
            guard let table = view as? NSTableView, table.selectionHighlightStyle != .none else { return }
            table.selectionHighlightStyle = .none
        }
    }
}
