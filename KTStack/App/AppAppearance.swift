import AppKit
import KTStackKit

enum AppAppearance {
    @MainActor
    static func apply(_ appearance: AppPreferences.Appearance) {
        NSApp.appearance = nsAppearance(for: appearance)
    }

    static func nsAppearance(for appearance: AppPreferences.Appearance) -> NSAppearance? {
        switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
