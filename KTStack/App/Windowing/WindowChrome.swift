import AppKit

struct WindowChrome {
    var appearance: NSAppearance?
    var titleVisibility: NSWindow.TitleVisibility
    var titlebarAppearsTransparent: Bool
    var fullSizeContentView: Bool
    var toolbarStyle: NSWindow.ToolbarStyle?
    var tabbingIdentifier: String?
    var tabbingMode: NSWindow.TabbingMode

    static let legacy = WindowChrome(
        appearance: NSAppearance(named: .aqua),
        titleVisibility: .hidden,
        titlebarAppearsTransparent: true,
        fullSizeContentView: true,
        toolbarStyle: nil,
        tabbingIdentifier: nil,
        tabbingMode: .disallowed
    )

    static func native(tabbingIdentifier: String) -> WindowChrome {
        WindowChrome(
            appearance: nil,
            titleVisibility: .visible,
            titlebarAppearsTransparent: false,
            fullSizeContentView: false,
            toolbarStyle: .unified,
            tabbingIdentifier: tabbingIdentifier,
            tabbingMode: .preferred
        )
    }
}
