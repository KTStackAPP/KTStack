import KTPlatformContracts
import KTPluginKit
import KTStackCore

/// Một mục trên rail: 2 ngôn ngữ, 2 web engine, 4 DB/cache engine.
enum RuntimesCategory: Hashable {
    case php
    case node
    case nginx
    case apache
    case engine(ServiceEngine)

    var title: String {
        switch self {
        case .php: "PHP"
        case .node: "Node"
        case .nginx: "Nginx"
        case .apache: "Apache"
        case let .engine(engine): engine.displayName
        }
    }

    var description: String {
        switch self {
        case .php: "Default applies to new sites and terminals."
        case .node: "Default applies to terminals. Sites run their own server."
        case .nginx: "Front terminator and default per-site engine."
        case .apache: "Per-site engine over mod_proxy_fcgi."
        case .engine: "Data is stored separately per version."
        }
    }

    var systemImage: String {
        switch self {
        case .php: RuntimeLanguage.php.symbolName
        case .node: RuntimeLanguage.node.symbolName
        case .nginx, .apache: "server.rack"
        case let .engine(engine): engine.symbolName
        }
    }

    var tint: KTTint {
        switch self {
        case .php: KTIconTint.php
        case .node: KTIconTint.cube
        case .nginx, .apache: KTIconTint.globe
        case let .engine(engine): engine.tint
        }
    }

    var language: RuntimeLanguage? {
        switch self {
        case .php: .php
        case .node: .node
        default: nil
        }
    }

    var engine: ServiceEngine? {
        if case let .engine(engine) = self { return engine }
        return nil
    }
}
