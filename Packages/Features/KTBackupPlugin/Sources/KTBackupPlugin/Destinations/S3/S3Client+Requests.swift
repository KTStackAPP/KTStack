import Foundation

extension S3Client {
    func signed(_ request: HTTPRequestSpec, payloadHash: String) -> HTTPRequestSpec {
        SigV4Signer(credentials: configuration.credentials, region: configuration.region)
            .signed(request, payloadHash: payloadHash, date: now())
    }

    @discardableResult
    func perform(_ method: String, key: String?, query: [(String, String)] = [], headers: [String: String] = [:],
                 body: HTTPBody = .empty, payloadHash: String = SigV4Signer.emptyPayloadHash,
                 progress: BackupProgressHandler? = nil) async throws -> HTTPResponse {
        let spec = HTTPRequestSpec(method: method, url: configuration.url(key: key, query: query), headers: headers)
        let response = try await transport.send(signed(spec, payloadHash: payloadHash), body: body, progress: progress)
        guard response.isSuccess else { throw S3Responses.error(response, bucket: configuration.bucket) }
        return response
    }

    func listPage(prefix: String, delimiter: String?, token: String?, maxKeys: Int) async throws -> S3ListPage {
        var query = [("list-type", "2"), ("prefix", prefix), ("max-keys", String(maxKeys))]
        if let delimiter { query.append(("delimiter", delimiter)) }
        if let token { query.append(("continuation-token", token)) }
        return try S3Responses.listPage(try await perform("GET", key: nil, query: query).body)
    }

    func head(_ key: String) async throws -> RemoteBackupObject {
        let response = try await perform("HEAD", key: key)
        let name = String(key.split(separator: "/").last ?? "")
        return RemoteBackupObject(
            id: key,
            name: name,
            sizeBytes: Int64(response.header("Content-Length") ?? "") ?? 0,
            createdAt: BackupArchiveNaming.createdAt(name),
            planID: response.header(Self.planMetadata).flatMap(UUID.init(uuidString:)),
            sha256: response.header(Self.checksumMetadata)
        )
    }
}
