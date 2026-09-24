import SwiftUI

public struct KTMenuShortcut: Equatable {
    public let key: Character
    public let command: Bool
    public let shift: Bool
    public let option: Bool

    public static func parse(_ display: String) -> KTMenuShortcut? {
        var command = false, shift = false, option = false
        var key: Character?
        for ch in display {
            switch ch {
            case "⌘": command = true
            case "⇧": shift = true
            case "⌥": option = true
            default:
                guard key == nil, ch.isLetter || ch.isNumber else { return nil }
                key = Character(ch.lowercased())
            }
        }
        guard let key, command else { return nil }
        return KTMenuShortcut(key: key, command: command, shift: shift, option: option)
    }

    public var keyboardShortcut: KeyboardShortcut {
        var modifiers: EventModifiers = []
        if command { modifiers.insert(.command) }
        if shift { modifiers.insert(.shift) }
        if option { modifiers.insert(.option) }
        return KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
    }
}

public extension View {
    @ViewBuilder
    func ktMenuShortcut(_ display: String) -> some View {
        if let shortcut = KTMenuShortcut.parse(display) {
            keyboardShortcut(shortcut.keyboardShortcut)
        } else {
            self
        }
    }
}
