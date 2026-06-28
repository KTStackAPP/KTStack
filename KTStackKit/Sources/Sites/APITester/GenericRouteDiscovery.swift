import Foundation

public struct GenericRouteDiscovery: Sendable {
    public init() {}

    public func discover(baseURL: URL?, folder: URL) async -> [APIRoute] {
        if let baseURL {
            let fromSpec = await OpenAPIRouteDiscovery().discover(baseURL: baseURL)
            if !fromSpec.isEmpty { return fromSpec }
        }
        return PostmanCollectionDiscovery().discover(folder: folder)
    }
}
