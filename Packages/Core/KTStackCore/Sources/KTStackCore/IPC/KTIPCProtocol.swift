import Foundation

public struct KTIPCRequest: Codable, Sendable {
    public let id: String?
    public let method: String
    public let params: [String: String]?

    public init(id: String? = nil, method: String, params: [String: String]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct KTIPCResponse: Codable, Sendable {
    public let id: String?
    public let success: Bool
    public let result: String?
    public let error: String?

    public init(id: String? = nil, success: Bool, result: String? = nil, error: String? = nil) {
        self.id = id
        self.success = success
        self.result = result
        self.error = error
    }

    public static func ok(_ result: String, id: String? = nil) -> KTIPCResponse {
        KTIPCResponse(id: id, success: true, result: result, error: nil)
    }

    public static func fail(_ error: String, id: String? = nil) -> KTIPCResponse {
        KTIPCResponse(id: id, success: false, result: nil, error: error)
    }
}

public struct KTIPCSiteInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let domain: String
    public let path: String
    public let phpVersion: String
    public let secure: Bool
    public let backendPort: Int
    public let wildcardSubdomains: Bool

    public init(
        id: String,
        name: String,
        domain: String,
        path: String,
        phpVersion: String,
        secure: Bool,
        backendPort: Int,
        wildcardSubdomains: Bool = false
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.path = path
        self.phpVersion = phpVersion
        self.secure = secure
        self.backendPort = backendPort
        self.wildcardSubdomains = wildcardSubdomains
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, domain, path, phpVersion, secure, backendPort, wildcardSubdomains
    }

    // A `kt` newer than the running app reads a payload without wildcardSubdomains; default false.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        domain = try c.decode(String.self, forKey: .domain)
        path = try c.decode(String.self, forKey: .path)
        phpVersion = try c.decode(String.self, forKey: .phpVersion)
        secure = try c.decode(Bool.self, forKey: .secure)
        backendPort = try c.decode(Int.self, forKey: .backendPort)
        wildcardSubdomains = try c.decodeIfPresent(Bool.self, forKey: .wildcardSubdomains) ?? false
    }
}

public struct KTIPCServiceInfo: Codable, Sendable {
    public let name: String
    public let running: Bool
    public let detail: String?

    public init(name: String, running: Bool, detail: String? = nil) {
        self.name = name
        self.running = running
        self.detail = detail
    }
}
