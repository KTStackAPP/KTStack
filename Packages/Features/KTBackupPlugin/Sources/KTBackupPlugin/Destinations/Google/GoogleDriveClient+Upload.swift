import Foundation

extension GoogleDriveClient {
    enum UploadStatus: Equatable {
        case offset(Int64)
        case complete(DriveFile)
    }

    func resumableUpload(_ request: BackupUploadRequest, parentID: String,
                         progress: @escaping BackupProgressHandler) async throws -> DriveFile {
        let session = try await startSession(request, parentID: parentID)
        let handle = try FileHandle(forReadingFrom: request.fileURL)
        defer { try? handle.close() }
        var offset: Int64 = 0
        var failures = 0
        while true {
            try Task.checkCancellation()
            try handle.seek(toOffset: UInt64(offset))
            let length = Int(min(Int64(chunkSize), request.sizeBytes - offset))
            let chunk = try handle.read(upToCount: length) ?? Data()
            let status: UploadStatus
            do {
                status = try await putChunk(chunk, to: session, offset: offset, total: request.sizeBytes)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures += 1
                guard failures < Self.maxAttempts else { throw error }
                try await backoff(failures)
                status = try await queryStatus(session, total: request.sizeBytes)
            }
            switch status {
            case let .complete(file):
                progress(1)
                return file
            case let .offset(next):
                if next > offset { failures = 0 }
                offset = next
                progress(Double(offset) / Double(max(request.sizeBytes, 1)))
            }
        }
    }

    private func startSession(_ request: BackupUploadRequest, parentID: String) async throws -> URL {
        let metadata: [String: Any] = [
            "name": request.fileName,
            "parents": [parentID],
            "mimeType": "application/zip",
            "appProperties": [Self.planProperty: request.planID.uuidString, Self.checksumProperty: request.sha256]
        ]
        let response = try await send(
            "POST", Self.uploadBase,
            query: [("uploadType", "resumable"), ("fields", Self.fileFields)],
            headers: ["Content-Type": "application/json; charset=UTF-8", "X-Upload-Content-Type": "application/zip",
                      "X-Upload-Content-Length": String(request.sizeBytes)],
            body: .data(try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]))
        )
        guard response.isSuccess else { throw Self.error(response) }
        guard let location = response.header("Location"), let session = URL(string: location) else {
            throw BackupDestinationError.remote("Google Drive didn't open an upload session.")
        }
        return session
    }

    private func putChunk(_ chunk: Data, to session: URL, offset: Int64, total: Int64) async throws -> UploadStatus {
        let end = offset + Int64(chunk.count) - 1
        let spec = HTTPRequestSpec(method: "PUT", url: session, headers: ["Content-Range": "bytes \(offset)-\(end)/\(total)"])
        return try interpret(try await transport.send(spec, body: .data(chunk)))
    }

    func queryStatus(_ session: URL, total: Int64) async throws -> UploadStatus {
        let spec = HTTPRequestSpec(method: "PUT", url: session, headers: ["Content-Range": "bytes */\(total)"])
        return try interpret(try await transport.send(spec, body: .empty))
    }

    private func interpret(_ response: HTTPResponse) throws -> UploadStatus {
        switch response.status {
        case 200, 201:
            return .complete(try JSONDecoder().decode(DriveFile.self, from: response.body))
        case 308:
            return .offset(Self.nextOffset(response.header("Range")))
        case 404, 410:
            throw BackupDestinationError.remote("The Google Drive upload session expired; the backup will retry on the next run.")
        default:
            throw Self.error(response)
        }
    }

    static func nextOffset(_ range: String?) -> Int64 {
        guard let range, let last = range.split(separator: "-").last, let end = Int64(last) else { return 0 }
        return end + 1
    }
}
