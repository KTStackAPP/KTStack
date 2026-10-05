import CryptoKit
import Foundation

public struct SigV4Credentials: Equatable, Sendable {
    public var accessKeyID: String
    public var secretAccessKey: String
    public var sessionToken: String?

    public init(accessKeyID: String, secretAccessKey: String, sessionToken: String? = nil) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.sessionToken = sessionToken
    }
}

public struct SigV4Signer: Sendable {
    public static let unsignedPayload = "UNSIGNED-PAYLOAD"
    public static let emptyPayloadHash = sha256Hex(Data())
    static let algorithm = "AWS4-HMAC-SHA256"

    public let credentials: SigV4Credentials
    public let region: String
    public let service: String
    public let includesContentHashHeader: Bool

    public init(credentials: SigV4Credentials, region: String, service: String = "s3", includesContentHashHeader: Bool = true) {
        self.credentials = credentials
        self.region = region
        self.service = service
        self.includesContentHashHeader = includesContentHashHeader
    }

    public func signed(_ request: HTTPRequestSpec, payloadHash: String, date: Date) -> HTTPRequestSpec {
        var signed = request
        let amzDate = Self.timestamp(date, format: "yyyyMMdd'T'HHmmss'Z'")
        if !signed.headers.keys.contains(where: { $0.lowercased() == "host" }) {
            signed.headers["Host"] = Self.hostHeader(request.url)
        }
        signed.headers["X-Amz-Date"] = amzDate
        if includesContentHashHeader { signed.headers["X-Amz-Content-Sha256"] = payloadHash }
        if let token = credentials.sessionToken { signed.headers["X-Amz-Security-Token"] = token }
        let canonical = canonicalHeaders(signed.headers)
        let scope = "\(String(amzDate.prefix(8)))/\(region)/\(service)/aws4_request"
        let request = canonicalRequest(signed, headers: canonical, payloadHash: payloadHash)
        let toSign = [Self.algorithm, amzDate, scope, Self.sha256Hex(Data(request.utf8))].joined(separator: "\n")
        let signature = Self.hex(HMAC<SHA256>.authenticationCode(for: Data(toSign.utf8), using: signingKey(String(amzDate.prefix(8)))))
        let signedHeaders = canonical.map(\.0).joined(separator: ";")
        signed.headers["Authorization"] =
            "\(Self.algorithm) Credential=\(credentials.accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        return signed
    }

    func canonicalRequest(_ request: HTTPRequestSpec, headers: [(String, String)], payloadHash: String) -> String {
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        let rawPath = components?.percentEncodedPath ?? "/"
        let path = URLEncoding.path(rawPath.removingPercentEncoding ?? rawPath)
        return [
            request.method,
            path.isEmpty ? "/" : path,
            canonicalQuery(components?.percentEncodedQuery),
            headers.map { "\($0.0):\($0.1)\n" }.joined(),
            headers.map(\.0).joined(separator: ";"),
            payloadHash
        ].joined(separator: "\n")
    }

    func canonicalQuery(_ query: String?) -> String {
        guard let query, !query.isEmpty else { return "" }
        let items = query.split(separator: "&").map { pair -> (String, String) in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let key = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            return (key, value)
        }
        return URLEncoding.query(items)
    }

    func canonicalHeaders(_ headers: [String: String]) -> [(String, String)] {
        headers.map { name, value in
            let collapsed = value.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            return (name.lowercased(), collapsed.trimmingCharacters(in: .whitespaces))
        }
        .sorted { $0.0 < $1.0 }
    }

    func signingKey(_ dateStamp: String) -> SymmetricKey {
        let secret = SymmetricKey(data: Data("AWS4\(credentials.secretAccessKey)".utf8))
        let dateKey = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(dateStamp.utf8), using: secret)))
        let regionKey = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(region.utf8), using: dateKey)))
        let serviceKey = SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data(service.utf8), using: regionKey)))
        return SymmetricKey(data: Data(HMAC<SHA256>.authenticationCode(for: Data("aws4_request".utf8), using: serviceKey)))
    }

    public static func sha256Hex(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    static func hex<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hostHeader(_ url: URL) -> String {
        guard let host = url.host else { return "" }
        guard let port = url.port, !(url.scheme == "https" && port == 443), !(url.scheme == "http" && port == 80) else {
            return host
        }
        return "\(host):\(port)"
    }

    static func timestamp(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
