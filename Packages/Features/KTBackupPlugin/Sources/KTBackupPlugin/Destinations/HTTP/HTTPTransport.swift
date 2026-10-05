import Foundation

public struct HTTPRequestSpec: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]

    public init(method: String, url: URL, headers: [String: String] = [:]) {
        self.method = method
        self.url = url
        self.headers = headers
    }
}

public enum HTTPBody: Equatable, Sendable {
    case empty
    case data(Data)
    case file(URL)
}

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    public var isSuccess: Bool {
        (200..<300).contains(status)
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequestSpec, body: HTTPBody, progress: BackupProgressHandler?) async throws -> HTTPResponse
    func download(_ request: HTTPRequestSpec, to fileURL: URL, progress: BackupProgressHandler?) async throws -> HTTPResponse
}

public extension HTTPTransport {
    func send(_ request: HTTPRequestSpec, body: HTTPBody = .empty) async throws -> HTTPResponse {
        try await send(request, body: body, progress: nil)
    }
}

enum URLEncoding {
    static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func strict(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }

    static func path(_ text: String) -> String {
        text.split(separator: "/", omittingEmptySubsequences: false).map { strict(String($0)) }.joined(separator: "/")
    }

    static func query(_ items: [(String, String)]) -> String {
        let encoded: [(key: String, value: String)] = items.map { (key: strict($0.0), value: strict($0.1)) }
        let sorted = encoded.sorted { lhs, rhs in
            lhs.key == rhs.key ? lhs.value < rhs.value : lhs.key < rhs.key
        }
        return sorted.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    }

    static func form(_ items: [(String, String)]) -> Data {
        Data(items.map { "\(strict($0.0))=\(strict($0.1))" }.joined(separator: "&").utf8)
    }
}
