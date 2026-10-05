import Foundation

public struct GoogleDriveClient: BackupDestinationClient {
    static let planProperty = "ktstackPlan"
    static let checksumProperty = "ktstackSha256"
    static let apiBase = "https://www.googleapis.com/drive/v3"
    static let uploadBase = "https://www.googleapis.com/upload/drive/v3/files"
    static let fileFields = "id,name,mimeType,size,md5Checksum,createdTime,trashed,appProperties"

    public let folderID: String
    let tokens: GoogleAccessTokenProvider
    let transport: any HTTPTransport
    let chunkSize: Int
    let retryBaseDelay: UInt64

    public init(folderID: String, tokens: GoogleAccessTokenProvider, transport: any HTTPTransport,
                chunkSize: Int = 32 * 256 * 1024, retryBaseDelay: UInt64 = 1_000_000_000) {
        self.folderID = folderID
        self.tokens = tokens
        self.transport = transport
        self.chunkSize = chunkSize
        self.retryBaseDelay = retryBaseDelay
    }

    public func accountEmail() async throws -> String {
        let about: DriveAbout = try await json("GET", "\(Self.apiBase)/about", query: [("fields", "user(emailAddress)")])
        return about.user?.emailAddress ?? ""
    }

    public func testConnection() async throws -> String {
        let email = try await accountEmail()
        guard !folderID.isEmpty else { throw BackupDestinationError.notConfigured("choose a Drive folder.") }
        let folder = try await folderMetadata()
        return "Connected as \(email) · folder \"\(folder.name)\""
    }

    public func listFolders(parent: RemoteFolder?) async throws -> [RemoteFolder] {
        var folders: [RemoteFolder] = []
        var token: String?
        repeat {
            var query = [("q", DriveQuery.folders(in: parent?.id ?? "root")), ("fields", "nextPageToken,files(id,name)"),
                         ("pageSize", "100"), ("orderBy", "name")]
            if let token { query.append(("pageToken", token)) }
            let page: DriveFileList = try await json("GET", "\(Self.apiBase)/files", query: query)
            folders += page.files.map { RemoteFolder(id: $0.id, name: $0.name) }
            token = page.nextPageToken
        } while token != nil
        return folders
    }

    public func createFolder(named name: String, in parent: RemoteFolder?) async throws -> RemoteFolder {
        let body: [String: Any] = ["name": name, "mimeType": DriveQuery.folderMimeType, "parents": [parent?.id ?? "root"]]
        let file: DriveFile = try await json("POST", "\(Self.apiBase)/files", query: [("fields", "id,name")], body: body)
        return RemoteFolder(id: file.id, name: file.name)
    }

    public func upload(_ request: BackupUploadRequest, progress: @escaping BackupProgressHandler) async throws -> RemoteBackupObject {
        let parent = try await planFolder(named: request.planFolderName)
        let file = try await resumableUpload(request, parentID: parent.id, progress: progress)
        let localMD5 = try FileDigest.md5Hex(of: request.fileURL)
        guard file.md5Checksum == localMD5, Int64(file.size ?? "") == request.sizeBytes else {
            throw BackupDestinationError.verificationFailed("Google Drive reports a different checksum for \(request.fileName).")
        }
        return file.remoteObject()
    }

    public func list(ownedBy planID: UUID) async throws -> [RemoteBackupObject] {
        var objects: [RemoteBackupObject] = []
        var token: String?
        repeat {
            var query = [("q", DriveQuery.owned(by: planID)), ("fields", "nextPageToken,files(\(Self.fileFields))"), ("pageSize", "100")]
            if let token { query.append(("pageToken", token)) }
            let page: DriveFileList = try await json("GET", "\(Self.apiBase)/files", query: query)
            objects += page.files.map { $0.remoteObject() }
            token = page.nextPageToken
        } while token != nil
        return objects
    }

    public func moveToTrash(_ object: RemoteBackupObject) async throws -> TrashOutcome {
        let _: DriveFile = try await json("PATCH", "\(Self.apiBase)/files/\(URLEncoding.strict(object.id))",
                                          query: [("fields", "id,name,trashed")], body: ["trashed": true])
        return .trashed
    }

    public func download(_ object: RemoteBackupObject, to fileURL: URL, progress: @escaping BackupProgressHandler) async throws {
        let url = URL(string: "\(Self.apiBase)/files/\(URLEncoding.strict(object.id))?alt=media")!
        let response = try await authorized { token in
            try await transport.download(HTTPRequestSpec(method: "GET", url: url, headers: ["Authorization": "Bearer \(token)"]),
                                         to: fileURL, progress: progress)
        }
        guard response.isSuccess else { throw Self.error(response) }
    }

    func folderMetadata() async throws -> DriveFile {
        do {
            let folder: DriveFile = try await json("GET", "\(Self.apiBase)/files/\(URLEncoding.strict(folderID))",
                                                   query: [("fields", "id,name,trashed,mimeType")])
            guard folder.trashed != true else { throw Self.folderGone }
            return folder
        } catch let error as BackupDestinationError where error == .remote("Not found (HTTP 404).") {
            throw Self.folderGone
        }
    }

    static let folderGone = BackupDestinationError.unavailable(
        "The Drive folder was deleted, moved to the Trash or is no longer shared with KTStack. Choose another folder."
    )

    private func planFolder(named name: String) async throws -> RemoteFolder {
        _ = try await folderMetadata()
        let page: DriveFileList = try await json("GET", "\(Self.apiBase)/files",
                                                 query: [("q", DriveQuery.folder(named: name, in: folderID)), ("fields", "files(id,name)")])
        if let existing = page.files.first { return RemoteFolder(id: existing.id, name: existing.name) }
        return try await createFolder(named: name, in: RemoteFolder(id: folderID, name: ""))
    }
}
