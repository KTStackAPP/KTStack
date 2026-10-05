import Foundation
import XCTest
@testable import KTBackupPlugin

final class S3ClientTests: XCTestCase {
    private let configuration = S3Configuration(
        endpoint: URL(string: "http://127.0.0.1:9000")!, region: "us-east-1", bucket: "backups", prefix: "/kt/",
        usePathStyle: true, credentials: SigV4Credentials(accessKeyID: "minio", secretAccessKey: "minio123")
    )

    private func client(_ responders: [ScriptedTransport.Responder], threshold: Int64 = 100 << 20, partSize: Int = 16 << 20)
        -> (S3Client, ScriptedTransport) {
        let transport = ScriptedTransport(responders)
        return (S3Client(configuration: configuration, transport: transport, multipartThreshold: threshold, partSize: partSize), transport)
    }

    private func request(size: Int = 32) throws -> (BackupUploadRequest, BackupPlan) {
        let plan = BackupPlan(name: "Shop")
        let name = BackupArchiveNaming.fileName(for: plan, at: date("2026-05-10 02:00:00"))
        let file = try makeTemporaryDirectory().appendingPathComponent(name)
        try Data(repeating: 7, count: size).write(to: file)
        let upload = BackupUploadRequest(fileURL: file, fileName: name, planFolderName: "Shop", planID: plan.id,
                                         sha256: try FileDigest.sha256Hex(of: file), sizeBytes: Int64(size))
        return (upload, plan)
    }

    private func headResponse(_ request: BackupUploadRequest, sha: String? = nil) -> ScriptedTransport.Responder {
        { _, _ in
            HTTPResponse(status: 200, headers: ["Content-Length": "\(request.sizeBytes)",
                                                S3Client.planMetadata: request.planID.uuidString,
                                                S3Client.checksumMetadata: sha ?? request.sha256])
        }
    }

    func testURLBuildingForPathAndVirtualHostedStyle() {
        XCTAssertEqual(configuration.url(key: "kt/a b.ktbackup").absoluteString, "http://127.0.0.1:9000/backups/kt/a%20b.ktbackup")
        var virtual = configuration
        virtual.endpoint = URL(string: "https://s3.eu-west-1.amazonaws.com")!
        virtual.usePathStyle = false
        XCTAssertEqual(virtual.url(key: "kt/x", query: [("list-type", "2"), ("prefix", "kt/")]).absoluteString,
                       "https://backups.s3.eu-west-1.amazonaws.com/kt/x?list-type=2&prefix=kt%2F")
        XCTAssertEqual(configuration.prefix, "kt/")
        XCTAssertEqual(configuration.key("Shop", "a.ktbackup"), "kt/Shop/a.ktbackup")
    }

    func testSinglePutUploadIsVerifiedWithHead() async throws {
        let (upload, _) = try request()
        let (client, transport) = client([{ _, _ in HTTPResponse(status: 200) }, headResponse(upload)])
        let object = try await client.upload(upload) { _ in }
        XCTAssertEqual(object.id, "kt/Shop/\(upload.fileName)")
        XCTAssertEqual(transport.methods, ["PUT /backups/kt/Shop/\(upload.fileName)", "HEAD /backups/kt/Shop/\(upload.fileName)"])
        let put = transport.requests[0].0
        XCTAssertEqual(put.headers[S3Client.checksumMetadata], upload.sha256)
        XCTAssertEqual(put.headers["X-Amz-Content-Sha256"], upload.sha256)
        XCTAssertEqual(transport.requests[0].1, .file(upload.fileURL))
    }

    func testChecksumMismatchFailsVerification() async throws {
        let (upload, _) = try request()
        let (client, _) = client([{ _, _ in HTTPResponse(status: 200) }, headResponse(upload, sha: "bad")])
        do {
            _ = try await client.upload(upload) { _ in }
            XCTFail("expected verification failure")
        } catch let error as BackupDestinationError {
            guard case .verificationFailed = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testMultipartUploadSplitsPartsAndCompletes() async throws {
        let (upload, _) = try request(size: 25)
        let initiate = Data("<InitiateMultipartUploadResult><UploadId>U1</UploadId></InitiateMultipartUploadResult>".utf8)
        let part: ScriptedTransport.Responder = { spec, _ in
            HTTPResponse(status: 200, headers: ["ETag": "\"e-\(spec.url.query ?? "")\""])
        }
        let (client, transport) = client([
            { _, _ in HTTPResponse(status: 200, body: initiate) }, part, part, part,
            { _, _ in HTTPResponse(status: 200, body: Data("<CompleteMultipartUploadResult/>".utf8)) },
            headResponse(upload)
        ], threshold: 10, partSize: 10)
        _ = try await client.upload(upload) { _ in }
        let sizes = transport.requests[1...3].map { request -> Int in
            if case let .data(chunk) = request.1 { return chunk.count }
            return -1
        }
        XCTAssertEqual(sizes, [10, 10, 5])
        guard case let .data(completeBody) = transport.requests[4].1 else { return XCTFail("missing complete body") }
        let xml = String(decoding: completeBody, as: UTF8.self)
        XCTAssertTrue(xml.hasPrefix("<CompleteMultipartUpload><Part><PartNumber>1</PartNumber>"))
        XCTAssertEqual(xml.components(separatedBy: "<Part>").count - 1, 3)
        XCTAssertTrue(transport.requests[4].0.url.query?.contains("uploadId=U1") == true)
    }

    func testMultipartFailureAbortsUpload() async throws {
        let (upload, _) = try request(size: 25)
        let initiate = Data("<InitiateMultipartUploadResult><UploadId>U9</UploadId></InitiateMultipartUploadResult>".utf8)
        let failing: ScriptedTransport.Responder = { _, _ in HTTPResponse(status: 500) }
        let (client, transport) = client([
            { _, _ in HTTPResponse(status: 200, body: initiate) }, failing, failing, failing,
            { _, _ in HTTPResponse(status: 204) }
        ], threshold: 10, partSize: 10)
        do {
            _ = try await client.upload(upload) { _ in }
            XCTFail("expected failure")
        } catch {}
        XCTAssertEqual(transport.requests.last?.0.method, "DELETE")
        XCTAssertTrue(transport.requests.last?.0.url.query?.contains("uploadId=U9") == true)
    }

    func testPartRanges() {
        let ranges = S3Client.partRanges(size: 35, partSize: 16)
        XCTAssertEqual(ranges.map(\.length), [16, 16, 3])
        XCTAssertEqual(ranges.map(\.offset), [0, 16, 32])
        XCTAssertEqual(ranges.map(\.number), [1, 2, 3])
    }

    func testListFoldersParsesCommonPrefixesAndHidesTrash() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><IsTruncated>false</IsTruncated>
        <CommonPrefixes><Prefix>kt/.trash/</Prefix></CommonPrefixes>
        <CommonPrefixes><Prefix>kt/Shop/</Prefix></CommonPrefixes></ListBucketResult>
        """
        let (client, transport) = client([{ _, _ in HTTPResponse(status: 200, body: Data(xml.utf8)) }])
        let folders = try await client.listFolders(parent: RemoteFolder(id: "kt/", name: "kt"))
        XCTAssertEqual(folders, [RemoteFolder(id: "kt/Shop/", name: "Shop")])
        XCTAssertTrue(transport.requests[0].0.url.query?.contains("delimiter=%2F") == true)
    }

    func testListOwnedFiltersByNameAndMetadata() async throws {
        let (upload, plan) = try request()
        let foreign = "kt/Shop/notes.txt"
        let xml = """
        <ListBucketResult><IsTruncated>false</IsTruncated>
        <Contents><Key>kt/Shop/\(upload.fileName)</Key><Size>32</Size><LastModified>2026-05-10T02:00:05.000Z</LastModified></Contents>
        <Contents><Key>\(foreign)</Key><Size>3</Size></Contents>
        <Contents><Key>kt/.trash/Shop/\(upload.fileName)</Key><Size>32</Size></Contents></ListBucketResult>
        """
        let (client, transport) = client([{ _, _ in HTTPResponse(status: 200, body: Data(xml.utf8)) }, headResponse(upload)])
        let owned = try await client.list(ownedBy: plan.id)
        XCTAssertEqual(owned.map(\.id), ["kt/Shop/\(upload.fileName)"])
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testMoveToTrashCopiesThenDeletes() async throws {
        let object = RemoteBackupObject(id: "kt/Shop/a.ktbackup", name: "a.ktbackup", sizeBytes: 1, createdAt: nil, planID: nil, sha256: nil)
        let (client, transport) = client([
            { _, _ in HTTPResponse(status: 200, body: Data("<CopyObjectResult/>".utf8)) },
            { _, _ in HTTPResponse(status: 204) }
        ])
        let outcome = try await client.moveToTrash(object)
        XCTAssertEqual(outcome, .trashed)
        XCTAssertEqual(transport.methods, ["PUT /backups/kt/.trash/Shop/a.ktbackup", "DELETE /backups/kt/Shop/a.ktbackup"])
        XCTAssertEqual(transport.requests[0].0.headers["x-amz-copy-source"], "/backups/kt/Shop/a.ktbackup")
    }

    func testErrorMessagesFromS3XML() {
        func error(_ status: Int, _ body: String) -> String {
            S3Responses.error(HTTPResponse(status: status, body: Data(body.utf8)), bucket: "backups").localizedDescription
        }
        XCTAssertEqual(error(404, "<Error><Code>NoSuchBucket</Code></Error>"), "The bucket \"backups\" doesn't exist.")
        XCTAssertTrue(error(403, "<Error><Code>AccessDenied</Code></Error>").hasPrefix("Access denied"))
        XCTAssertTrue(error(400, "<Error><Code>AuthorizationHeaderMalformed</Code><Region>eu-west-1</Region></Error>")
            .contains("eu-west-1"))
        XCTAssertTrue(error(403, "<Error><Code>SignatureDoesNotMatch</Code></Error>").contains("secret access key"))
        XCTAssertEqual(error(403, ""), "Access denied (HTTP 403).")
    }
}
