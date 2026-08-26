import KTPlatformContracts
import KTPluginKit

enum SiteVisuals {
    static func kind(for type: SiteKind) -> KTSiteIconKind {
        switch type {
        case .php: .code
        case .node: .cube
        case .staticSite: .db
        }
    }

    static func tint(for type: SiteKind) -> KTTint {
        switch type {
        case .php: KTIconTint.code
        case .node: KTIconTint.cube
        case .staticSite: KTIconTint.db
        }
    }

    static func tint(for framework: PHPFramework) -> KTTint {
        switch framework {
        case .wordpress: KTIconTint.wordpress
        case .laravel: KTIconTint.laravel
        case .plain: KTIconTint.php
        }
    }

    static func label(for type: SiteKind) -> String {
        switch type {
        case .php: "PHP"
        case .staticSite: "Static"
        case .node: "Node"
        }
    }

    static func symbolName(for type: SiteKind) -> String {
        switch type {
        case .php: "chevron.left.forwardslash.chevron.right"
        case .staticSite: "doc.richtext"
        case .node: "shippingbox"
        }
    }
}
