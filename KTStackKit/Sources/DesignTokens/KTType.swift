import SwiftUI

public extension Font {
    static func jbMono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .bold, .heavy, .black: face = "JetBrainsMono-Bold"
        case .semibold: face = "JetBrainsMono-SemiBold"
        case .medium: face = "JetBrainsMono-Medium"
        default: face = "JetBrainsMono-Regular"
        }
        return .custom(face, size: size)
    }
}

public enum KTType {
    public static let screenTitle = Font.jbMono(20, .bold)
    public static let modalTitle = Font.jbMono(17, .bold)
    public static let cardName = Font.jbMono(14, .semibold)
    public static let rowName = Font.jbMono(13.5, .semibold)
    public static let label = Font.jbMono(13, .semibold)
    public static let body = Font.jbMono(13)
    public static let control = Font.jbMono(12.5, .medium)
    public static let sub = Font.jbMono(12)
    public static let sub13 = Font.jbMono(12.5)
    public static let caption = Font.jbMono(11)
    public static let sectionLabel = Font.jbMono(11, .bold)
    public static let settingsLabel = Font.jbMono(12, .bold)
    public static let mono = Font.jbMono(13)
    public static let monoSmall = Font.jbMono(12.5)

    public static let screenTitleTracking: CGFloat = -0.5
    public static let sectionLabelTracking: CGFloat = 0.6
}
