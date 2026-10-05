import Foundation

public enum S3Preset: String, Codable, Sendable, CaseIterable, Identifiable {
    case aws, cloudflareR2, backblazeB2, minio, wasabi, digitalOceanSpaces, custom

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .aws: "Amazon S3"
        case .cloudflareR2: "Cloudflare R2"
        case .backblazeB2: "Backblaze B2"
        case .minio: "MinIO"
        case .wasabi: "Wasabi"
        case .digitalOceanSpaces: "DigitalOcean Spaces"
        case .custom: "Custom"
        }
    }

    public var defaultRegion: String {
        switch self {
        case .aws, .minio, .wasabi, .custom: "us-east-1"
        case .cloudflareR2: "auto"
        case .backblazeB2: "us-west-004"
        case .digitalOceanSpaces: "nyc3"
        }
    }

    public var usesPathStyle: Bool {
        self == .minio || self == .cloudflareR2 || self == .custom
    }

    public var endpointHint: String {
        switch self {
        case .aws: "https://s3.<region>.amazonaws.com"
        case .cloudflareR2: "https://<account-id>.r2.cloudflarestorage.com"
        case .backblazeB2: "https://s3.<region>.backblazeb2.com"
        case .minio: "http://127.0.0.1:9000"
        case .wasabi: "https://s3.<region>.wasabisys.com"
        case .digitalOceanSpaces: "https://<region>.digitaloceanspaces.com"
        case .custom: "https://s3.example.com"
        }
    }

    public func endpoint(region: String) -> String {
        switch self {
        case .aws: "https://s3.\(region).amazonaws.com"
        case .backblazeB2: "https://s3.\(region).backblazeb2.com"
        case .wasabi: "https://s3.\(region).wasabisys.com"
        case .digitalOceanSpaces: "https://\(region).digitaloceanspaces.com"
        case .minio: "http://127.0.0.1:9000"
        case .cloudflareR2, .custom: ""
        }
    }
}
