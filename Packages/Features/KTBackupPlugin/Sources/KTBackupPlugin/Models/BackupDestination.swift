import Foundation

public enum BackupDestinationKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case local, s3, googleDrive

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .local: "Local Folder"
        case .s3: "S3-Compatible"
        case .googleDrive: "Google Drive"
        }
    }
}

public struct LocalFolderSettings: Codable, Equatable, Sendable {
    public var path: String

    public init(path: String) {
        self.path = path
    }
}

public struct S3Settings: Codable, Equatable, Sendable {
    public var preset: S3Preset
    public var endpoint: String
    public var region: String
    public var bucket: String
    public var prefix: String
    public var accessKeyID: String
    public var usePathStyle: Bool

    public init(preset: S3Preset, endpoint: String, region: String, bucket: String, prefix: String,
                accessKeyID: String, usePathStyle: Bool) {
        self.preset = preset
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.prefix = prefix
        self.accessKeyID = accessKeyID
        self.usePathStyle = usePathStyle
    }
}

public struct GoogleDriveSettings: Codable, Equatable, Sendable {
    public var folderID: String
    public var folderName: String
    public var accountEmail: String
    public var customClientID: String?

    public init(folderID: String = "", folderName: String = "", accountEmail: String = "", customClientID: String? = nil) {
        self.folderID = folderID
        self.folderName = folderName
        self.accountEmail = accountEmail
        self.customClientID = customClientID
    }
}

public struct DestinationTestResult: Codable, Equatable, Sendable {
    public var testedAt: Date
    public var succeeded: Bool
    public var message: String

    public init(testedAt: Date, succeeded: Bool, message: String) {
        self.testedAt = testedAt
        self.succeeded = succeeded
        self.message = message
    }
}

public struct BackupDestination: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: BackupDestinationKind
    public var local: LocalFolderSettings?
    public var s3: S3Settings?
    public var googleDrive: GoogleDriveSettings?
    public var lastTest: DestinationTestResult?

    public init(id: UUID = UUID(), name: String, kind: BackupDestinationKind, local: LocalFolderSettings? = nil,
                s3: S3Settings? = nil, googleDrive: GoogleDriveSettings? = nil, lastTest: DestinationTestResult? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.local = local
        self.s3 = s3
        self.googleDrive = googleDrive
        self.lastTest = lastTest
    }

    public var targetDescription: String {
        switch kind {
        case .local:
            return local?.path ?? "No folder"
        case .s3:
            guard let s3 else { return "Not configured" }
            return s3.prefix.isEmpty ? "s3://\(s3.bucket)" : "s3://\(s3.bucket)/\(s3.prefix)"
        case .googleDrive:
            guard let drive = googleDrive, !drive.folderID.isEmpty else { return "No folder" }
            return drive.folderName.isEmpty ? drive.folderID : drive.folderName
        }
    }
}
