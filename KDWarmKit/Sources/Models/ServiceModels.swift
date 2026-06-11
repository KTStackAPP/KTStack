import SwiftUI

/// Service / site lifecycle state. Each state carries its own color + SF Symbol so
/// callers never rely on color alone (design-guidelines §3.2, §9 — WCAG 1.4.1).
public enum ServiceStatus: String, CaseIterable, Sendable {
    case running, stopped, starting, warning, error, info

    public var color: Color {
        switch self {
        case .running:  return .KDStatus.running
        case .stopped:  return .KDStatus.stopped
        case .starting: return .KDStatus.starting
        case .warning:  return .KDStatus.warning
        case .error:    return .KDStatus.error
        case .info:     return .KDStatus.info
        }
    }

    public var symbolName: String {
        switch self {
        case .running:  return "circle.fill"
        case .stopped:  return "circle"
        case .starting: return "circle.dotted"
        case .warning:  return "exclamationmark.triangle.fill"
        case .error:    return "xmark.octagon.fill"
        case .info:     return "info.circle"
        }
    }

    public var label: String {
        switch self {
        case .running:  return "Running"
        case .stopped:  return "Stopped"
        case .starting: return "Starting"
        case .warning:  return "Warning"
        case .error:    return "Error"
        case .info:     return "Info"
        }
    }
}

/// How a registered folder is served. A static or Node site must NOT be routed through
/// PHP-FPM (that yields 502/blank), so the type drives which vhost template is generated.
public enum SiteType: String, Codable, CaseIterable, Sendable {
    case php            // has index.php / PHP framework layout → fastcgi to a version socket
    case staticSite     // plain HTML/static assets → try_files, no fastcgi
    case node           // package.json present → served static for now (proxy_pass: Phase 7)

    public var label: String {
        switch self {
        case .php:        return "PHP"
        case .staticSite: return "Static"
        case .node:       return "Node"
        }
    }
    public var symbolName: String {
        switch self {
        case .php:        return "chevron.left.forwardslash.chevron.right"
        case .staticSite: return "doc.richtext"
        case .node:       return "shippingbox"
        }
    }
}

/// A manually-registered site (Valet-`link`-style) served at `<domain>` (default
/// `<dirname>.test`). The registry persists these to `config/sites/sites.json`.
public struct Site: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String        // registered folder's display name (dir name)
    public var path: String        // the registered folder (absolute)
    public var docroot: String     // resolved document root served by nginx (absolute)
    public var domain: String      // editable; must end in a wildcarded TLD (.test in MVP)
    public var phpVersion: String  // one of the bundled versions, e.g. "8.4"
    public var type: SiteType
    public var secure: Bool        // HTTPS — placeholder until Phase 5

    public init(id: UUID = UUID(),
                name: String,
                path: String,
                docroot: String,
                domain: String,
                phpVersion: String,
                type: SiteType,
                secure: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.docroot = docroot
        self.domain = domain
        self.phpVersion = phpVersion
        self.type = type
        self.secure = secure
    }

    public static let sample: [Site] = []
}
