import Foundation

public struct S3ObjectSummary: Equatable, Sendable {
    public var key: String
    public var size: Int64
    public var lastModified: Date?
}

public struct S3ListPage: Equatable, Sendable {
    public var objects: [S3ObjectSummary]
    public var commonPrefixes: [String]
    public var nextContinuationToken: String?
}

enum S3Responses {
    static func listPage(_ data: Data) throws -> S3ListPage {
        guard let root = XMLTree.parse(data), root.name == "ListBucketResult" else {
            throw BackupDestinationError.remote("S3 returned an unreadable object listing.")
        }
        let objects = root.children("Contents").compactMap { node -> S3ObjectSummary? in
            guard let key = node.value("Key") else { return nil }
            return S3ObjectSummary(
                key: key,
                size: Int64(node.value("Size") ?? "") ?? 0,
                lastModified: node.value("LastModified").flatMap(parseDate)
            )
        }
        let prefixes = root.children("CommonPrefixes").compactMap { $0.value("Prefix") }
        let truncated = root.value("IsTruncated") == "true"
        return S3ListPage(objects: objects, commonPrefixes: prefixes,
                          nextContinuationToken: truncated ? root.value("NextContinuationToken") : nil)
    }

    static func uploadID(_ data: Data) throws -> String {
        guard let id = XMLTree.parse(data)?.value("UploadId"), !id.isEmpty else {
            throw BackupDestinationError.remote("S3 didn't return a multipart upload ID.")
        }
        return id
    }

    static func completeMultipartBody(_ parts: [(Int, String)]) -> Data {
        let entries = parts.sorted { $0.0 < $1.0 }.map { number, etag in
            "<Part><PartNumber>\(number)</PartNumber><ETag>\(escape(etag))</ETag></Part>"
        }
        return Data("<CompleteMultipartUpload>\(entries.joined())</CompleteMultipartUpload>".utf8)
    }

    static func error(_ response: HTTPResponse, bucket: String) -> BackupDestinationError {
        let tree = XMLTree.parse(response.body)
        let code = tree?.value("Code") ?? ""
        let message = tree?.value("Message") ?? ""
        switch code {
        case "NoSuchBucket":
            return .remote("The bucket \"\(bucket)\" doesn't exist.")
        case "AccessDenied", "AllAccessDisabled":
            return .remote("Access denied. Check the access key permissions and the bucket policy.")
        case "InvalidAccessKeyId":
            return .missingCredentials("the access key ID isn't recognised by the provider.")
        case "SignatureDoesNotMatch":
            return .missingCredentials("the secret access key is wrong.")
        case "AuthorizationHeaderMalformed", "PermanentRedirect", "IllegalLocationConstraintException":
            let region = tree?.value("Region").map { " The bucket is in \($0)." } ?? ""
            return .remote("Wrong region for this bucket.\(region)")
        default:
            break
        }
        if response.status == 403 { return .remote("Access denied (HTTP 403).") }
        if response.status == 404 { return .remote("Not found (HTTP 404).") }
        let detail = [code, message].filter { !$0.isEmpty }.joined(separator: ": ")
        return .remote("S3 request failed (HTTP \(response.status))\(detail.isEmpty ? "" : ": \(detail)")")
    }

    static func embeddedError(_ data: Data) -> Bool {
        XMLTree.parse(data)?.name == "Error"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
