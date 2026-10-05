import Foundation

public struct S3Configuration: Equatable, Sendable {
    public var endpoint: URL
    public var region: String
    public var bucket: String
    public var prefix: String
    public var usePathStyle: Bool
    public var credentials: SigV4Credentials

    public init(endpoint: URL, region: String, bucket: String, prefix: String, usePathStyle: Bool, credentials: SigV4Credentials) {
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.prefix = Self.normalizedPrefix(prefix)
        self.usePathStyle = usePathStyle
        self.credentials = credentials
    }

    public init(settings: S3Settings, secretAccessKey: String) throws {
        let trimmed = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: trimmed), endpoint.scheme != nil, endpoint.host != nil else {
            throw BackupDestinationError.notConfigured("the endpoint \"\(trimmed)\" isn't a valid URL.")
        }
        guard !settings.bucket.isEmpty else { throw BackupDestinationError.notConfigured("no bucket is set.") }
        guard !settings.accessKeyID.isEmpty, !secretAccessKey.isEmpty else {
            throw BackupDestinationError.missingCredentials("access key ID and secret access key are required.")
        }
        self.init(
            endpoint: endpoint,
            region: settings.region.isEmpty ? settings.preset.defaultRegion : settings.region,
            bucket: settings.bucket,
            prefix: settings.prefix,
            usePathStyle: settings.usePathStyle,
            credentials: SigV4Credentials(accessKeyID: settings.accessKeyID, secretAccessKey: secretAccessKey)
        )
    }

    public static func normalizedPrefix(_ prefix: String) -> String {
        let trimmed = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return trimmed.isEmpty ? "" : trimmed + "/"
    }

    public func key(_ components: String...) -> String {
        prefix + components.filter { !$0.isEmpty }.joined(separator: "/")
    }

    public var trashPrefix: String {
        prefix + ".trash/"
    }

    public func url(key: String? = nil, query: [(String, String)] = []) -> URL {
        var base = endpoint.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        if !usePathStyle, var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) {
            components.host = "\(bucket).\(endpoint.host ?? "")"
            components.path = ""
            base = components.url?.absoluteString ?? base
        } else {
            base += "/" + URLEncoding.strict(bucket)
        }
        var text = base + "/" + URLEncoding.path(key ?? "")
        if !query.isEmpty {
            text += "?" + URLEncoding.query(query)
        }
        return URL(string: text) ?? endpoint
    }

    public var copySourceBucketPath: String {
        "/" + URLEncoding.strict(bucket) + "/"
    }
}
