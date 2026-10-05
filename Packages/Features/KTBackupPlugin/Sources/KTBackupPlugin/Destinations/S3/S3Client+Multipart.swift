import Foundation

struct S3PartRange: Equatable {
    let number: Int
    let offset: Int64
    let length: Int
}

extension S3Client {
    static let partAttempts = 3

    static func partRanges(size: Int64, partSize: Int) -> [S3PartRange] {
        guard size > 0, partSize > 0 else { return [] }
        var ranges: [S3PartRange] = []
        var offset: Int64 = 0
        while offset < size {
            let length = Int(min(Int64(partSize), size - offset))
            ranges.append(S3PartRange(number: ranges.count + 1, offset: offset, length: length))
            offset += Int64(length)
        }
        return ranges
    }

    func multipartUpload(_ request: BackupUploadRequest, key: String, metadata: [String: String],
                         progress: @escaping BackupProgressHandler) async throws {
        var headers = metadata
        headers["Content-Type"] = "application/zip"
        let created = try await perform("POST", key: key, query: [("uploads", "")], headers: headers)
        let uploadID = try S3Responses.uploadID(created.body)
        do {
            let handle = try FileHandle(forReadingFrom: request.fileURL)
            defer { try? handle.close() }
            var etags: [(Int, String)] = []
            let ranges = Self.partRanges(size: request.sizeBytes, partSize: partSize)
            for range in ranges {
                try Task.checkCancellation()
                try handle.seek(toOffset: UInt64(range.offset))
                let chunk = try handle.read(upToCount: range.length) ?? Data()
                etags.append((range.number, try await uploadPart(chunk, number: range.number, key: key, uploadID: uploadID)))
                progress(Double(range.number) / Double(ranges.count))
            }
            let body = S3Responses.completeMultipartBody(etags)
            let completed = try await perform("POST", key: key, query: [("uploadId", uploadID)], body: .data(body),
                                              payloadHash: SigV4Signer.sha256Hex(body))
            if S3Responses.embeddedError(completed.body) {
                throw S3Responses.error(completed, bucket: configuration.bucket)
            }
        } catch {
            _ = try? await perform("DELETE", key: key, query: [("uploadId", uploadID)])
            throw error
        }
    }

    private func uploadPart(_ chunk: Data, number: Int, key: String, uploadID: String) async throws -> String {
        var lastError: Error = BackupDestinationError.remote("Part \(number) failed.")
        for attempt in 1...Self.partAttempts {
            do {
                let response = try await perform("PUT", key: key, query: [("partNumber", String(number)), ("uploadId", uploadID)],
                                                 body: .data(chunk), payloadHash: SigV4Signer.sha256Hex(chunk))
                guard let etag = response.header("ETag") else {
                    throw BackupDestinationError.remote("S3 didn't return an ETag for part \(number).")
                }
                return etag
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < Self.partAttempts {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError
    }
}
