import Foundation

public struct S3Client: BackupDestinationClient {
    static let planMetadata = "x-amz-meta-ktstack-plan"
    static let checksumMetadata = "x-amz-meta-ktstack-sha256"

    public let configuration: S3Configuration
    let transport: any HTTPTransport
    let multipartThreshold: Int64
    let partSize: Int
    let now: @Sendable () -> Date

    public init(configuration: S3Configuration, transport: any HTTPTransport, multipartThreshold: Int64 = 100 << 20,
                partSize: Int = 16 << 20, now: @escaping @Sendable () -> Date = { Date() }) {
        self.configuration = configuration
        self.transport = transport
        self.multipartThreshold = multipartThreshold
        self.partSize = partSize
        self.now = now
    }

    public func testConnection() async throws -> String {
        _ = try await listPage(prefix: configuration.prefix, delimiter: "/", token: nil, maxKeys: 1)
        let probe = configuration.key(".ktstack-probe-\(UUID().uuidString)")
        try await perform("PUT", key: probe, body: .data(Data("probe".utf8)), payloadHash: SigV4Signer.sha256Hex(Data("probe".utf8)))
        try await perform("DELETE", key: probe)
        return "Bucket \(configuration.bucket) is reachable and writable."
    }

    public func listFolders(parent: RemoteFolder?) async throws -> [RemoteFolder] {
        var folders: [RemoteFolder] = []
        var token: String?
        repeat {
            let page = try await listPage(prefix: parent?.id ?? "", delimiter: "/", token: token, maxKeys: 1000)
            folders += page.commonPrefixes.filter { !$0.hasSuffix(".trash/") }.map { prefix in
                RemoteFolder(id: prefix, name: String(prefix.dropLast().split(separator: "/").last ?? ""))
            }
            token = page.nextContinuationToken
        } while token != nil
        return folders
    }

    public func createFolder(named name: String, in parent: RemoteFolder?) async throws -> RemoteFolder {
        let cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let key = (parent?.id ?? "") + cleaned + "/"
        try await perform("PUT", key: key, body: .data(Data()), payloadHash: SigV4Signer.emptyPayloadHash)
        return RemoteFolder(id: key, name: cleaned)
    }

    public func upload(_ request: BackupUploadRequest, progress: @escaping BackupProgressHandler) async throws -> RemoteBackupObject {
        let key = configuration.key(request.planFolderName, request.fileName)
        let metadata = [Self.planMetadata: request.planID.uuidString, Self.checksumMetadata: request.sha256]
        if request.sizeBytes > multipartThreshold {
            try await multipartUpload(request, key: key, metadata: metadata, progress: progress)
        } else {
            var headers = metadata
            headers["Content-Type"] = "application/zip"
            try await perform("PUT", key: key, headers: headers, body: .file(request.fileURL), payloadHash: request.sha256, progress: progress)
        }
        let object = try await head(key)
        guard object.sizeBytes == request.sizeBytes, object.sha256 == request.sha256 else {
            throw BackupDestinationError.verificationFailed("the object stored at \(key) doesn't match the archive.")
        }
        return object
    }

    public func list(ownedBy planID: UUID) async throws -> [RemoteBackupObject] {
        var owned: [RemoteBackupObject] = []
        var token: String?
        repeat {
            let page = try await listPage(prefix: configuration.prefix, delimiter: nil, token: token, maxKeys: 1000)
            for summary in page.objects where !summary.key.hasPrefix(configuration.trashPrefix) {
                let name = String(summary.key.split(separator: "/").last ?? "")
                guard BackupArchiveNaming.belongs(name, to: planID) else { continue }
                let object = try await head(summary.key)
                if object.planID == planID { owned.append(object) }
            }
            token = page.nextContinuationToken
        } while token != nil
        return owned
    }

    public func moveToTrash(_ object: RemoteBackupObject) async throws -> TrashOutcome {
        let relative = object.id.hasPrefix(configuration.prefix) ? String(object.id.dropFirst(configuration.prefix.count)) : object.id
        let target = configuration.trashPrefix + relative
        let source = configuration.copySourceBucketPath + URLEncoding.path(object.id)
        let response = try await perform("PUT", key: target, headers: ["x-amz-copy-source": source])
        guard !S3Responses.embeddedError(response.body) else {
            throw S3Responses.error(response, bucket: configuration.bucket)
        }
        try await perform("DELETE", key: object.id)
        return .trashed
    }

    public func download(_ object: RemoteBackupObject, to fileURL: URL, progress: @escaping BackupProgressHandler) async throws {
        let request = signed(HTTPRequestSpec(method: "GET", url: configuration.url(key: object.id)), payloadHash: SigV4Signer.emptyPayloadHash)
        let response = try await transport.download(request, to: fileURL, progress: progress)
        guard response.isSuccess else { throw S3Responses.error(response, bucket: configuration.bucket) }
    }
}
