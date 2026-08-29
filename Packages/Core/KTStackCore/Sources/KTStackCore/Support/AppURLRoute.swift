import Foundation

// Parse ktstack:// deep links; giữ ở Core nên KTStackKitTests test được (App target không có test host).
public enum AppURLRoute: Equatable, Sendable {
    case database(profileID: UUID?)
    case unknown

    public static let scheme = "ktstack"

    public init(_ url: URL) {
        guard
            url.scheme?.lowercased() == Self.scheme,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            self = .unknown
            return
        }
        // ktstack://database → host "database"; ktstack:database cũng chấp nhận (path "database").
        let target = (components.host ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            .lowercased()
        switch target {
        case "database":
            let raw = components.queryItems?.first { $0.name == "profile" }?.value
            self = .database(profileID: raw.flatMap(UUID.init(uuidString:)))
        default:
            self = .unknown
        }
    }
}
