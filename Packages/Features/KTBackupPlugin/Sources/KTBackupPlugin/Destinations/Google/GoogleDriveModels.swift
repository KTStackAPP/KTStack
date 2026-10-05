import Foundation

struct DriveFile: Decodable, Equatable {
    var id: String
    var name: String
    var mimeType: String?
    var size: String?
    var md5Checksum: String?
    var createdTime: String?
    var trashed: Bool?
    var appProperties: [String: String]?

    func remoteObject() -> RemoteBackupObject {
        RemoteBackupObject(
            id: id,
            name: name,
            sizeBytes: Int64(size ?? "") ?? 0,
            createdAt: BackupArchiveNaming.createdAt(name) ?? createdTime.flatMap(Self.parseDate),
            planID: appProperties?[GoogleDriveClient.planProperty].flatMap(UUID.init(uuidString:)),
            sha256: appProperties?[GoogleDriveClient.checksumProperty]
        )
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}

struct DriveFileList: Decodable {
    var files: [DriveFile]
    var nextPageToken: String?
}

struct DriveAbout: Decodable {
    struct User: Decodable {
        var emailAddress: String?
    }

    var user: User?
}

struct DriveErrorReason: Decodable {
    var reason: String?
}

struct DriveErrorEnvelope: Decodable {
    struct Body: Decodable {
        var code: Int?
        var message: String?
        var errors: [DriveErrorReason]?
    }

    var error: Body
}

enum DriveQuery {
    static let folderMimeType = "application/vnd.google-apps.folder"

    static func literal(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
    }

    static func folders(in parentID: String) -> String {
        "\(literal(parentID)) in parents and mimeType = \(literal(folderMimeType)) and trashed = false"
    }

    static func folder(named name: String, in parentID: String) -> String {
        folders(in: parentID) + " and name = \(literal(name))"
    }

    static func owned(by planID: UUID) -> String {
        "appProperties has { key=\(literal(GoogleDriveClient.planProperty)) and value=\(literal(planID.uuidString)) } and trashed = false"
    }
}
