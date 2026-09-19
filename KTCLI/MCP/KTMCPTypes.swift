import Foundation

public struct KTMCPMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: KTMCPID?
    public let method: String?
    public let params: [String: AnyCodable]?
    public let result: [String: AnyCodable]?
    public let error: KTMCPErrorDetail?

    public init(
        jsonrpc: String = "2.0",
        id: KTMCPID? = nil,
        method: String? = nil,
        params: [String: AnyCodable]? = nil,
        result: [String: AnyCodable]? = nil,
        error: KTMCPErrorDetail? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }
}

public enum KTMCPID: Codable, Sendable, Equatable {
    case string(String)
    case number(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let num = try? container.decode(Int.self) {
            self = .number(num)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ID")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(str):
            try container.encode(str)
        case let .number(num):
            try container.encode(num)
        }
    }
}

public struct KTMCPErrorDetail: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = ()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let s as String: try container.encode(s)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let b as Bool: try container.encode(b)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        case let dict as [String: Any]:
            let wrapped = dict.mapValues { AnyCodable($0) }
            try container.encode(wrapped)
        case let arr as [AnyCodable]:
            try container.encode(arr)
        case let arr as [Any]:
            let wrapped = arr.map { AnyCodable($0) }
            try container.encode(wrapped)
        default:
            try container.encodeNil()
        }
    }
}
