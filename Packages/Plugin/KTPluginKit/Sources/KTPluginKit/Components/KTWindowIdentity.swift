import AppKit

public enum KTWindowIdentity {
    public static func matches(_ identifier: String?, sceneID: String) -> Bool {
        guard let identifier else { return false }
        return identifier == sceneID || identifier.hasPrefix(sceneID + "-")
    }

    public static func keepsAppInDock(
        isVisible: Bool,
        isMiniaturized: Bool,
        canBecomeMain: Bool,
        isPanel: Bool
    ) -> Bool {
        (isVisible || isMiniaturized) && canBecomeMain && !isPanel
    }

    @MainActor
    public static func window(sceneID: String, in windows: [NSWindow] = NSApp.windows) -> NSWindow? {
        windows.first { matches($0.identifier?.rawValue, sceneID: sceneID) && !($0 is NSPanel) }
    }
}
