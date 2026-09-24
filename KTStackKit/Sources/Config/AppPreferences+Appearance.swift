import Foundation

public extension AppPreferences {
    enum Appearance: String, CaseIterable, Sendable, Identifiable {
        case system, light, dark

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    static let appearanceKey = "KTStack.appearance"
}
