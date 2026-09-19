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

    public init(
        id: String,
        name: String,
        domain: String,
        path: String,
        phpVersion: String,
        secure: Bool,
        backendPort: Int
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.path = path
        self.phpVersion = phpVersion
        self.secure = secure
        self.backendPort = backendPort
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
