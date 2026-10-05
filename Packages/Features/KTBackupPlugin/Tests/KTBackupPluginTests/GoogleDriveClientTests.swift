import Foundation
import XCTest
@testable import KTBackupPlugin

final class GoogleDriveClientTests: XCTestCase {
    private func client(_ responders: [ScriptedTransport.Responder], chunkSize: Int = 10, tokenCount: Int = 2)
        -> (GoogleDriveClient, ScriptedTransport, ScriptedTransport) {
        let tokenBody = Data(#"{"access_token":"tok","expires_in":3600}"#.utf8)
        let tokenTransport = ScriptedTransport(Array(repeating: { _, _ in HTTPResponse(status: 200, body: tokenBody) }, count: tokenCount))
        let provider = GoogleAccessTokenProvider(
            tokenClient: GoogleTokenClient(client: GoogleOAuthClient(clientID: "id", clientSecret: nil), transport: tokenTransport),
            loadRefreshToken: { "1//r" }
        )
        let transport = ScriptedTransport(responders)
        return (GoogleDriveClient(folderID: "ROOT1", tokens: provider, transport: transport, chunkSize: chunkSize, retryBaseDelay: 0),
                transport, tokenTransport)
    }

    private func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> ScriptedTransport.Responder {
        { _, _ in HTTPResponse(status: status, headers: headers, body: Data(text.utf8)) }
    }

    private func upload(size: Int = 25) throws -> BackupUploadRequest {
        let plan = BackupPlan(name: "Shop")
        let name = BackupArchiveNaming.fileName(for: plan, at: date("2026-05-10 02:00:00"))
        let file = try makeTemporaryDirectory().appendingPathComponent(name)
        try Data((0..<size).map { UInt8($0 % 251) }).write(to: file)
        return BackupUploadRequest(fileURL: file, fileName: name, planFolderName: "Shop", planID: plan.id,
                                   sha256: try FileDigest.sha256Hex(of: file), sizeBytes: Int64(size))
    }

    private func uploadedFile(_ request: BackupUploadRequest, md5: String? = nil) throws -> String {
        let md5 = try md5 ?? FileDigest.md5Hex(of: request.fileURL)
        return """
        {"id":"F1","name":"\(request.fileName)","size":"\(request.sizeBytes)","md5Checksum":"\(md5)",
         "appProperties":{"ktstackPlan":"\(request.planID.uuidString)","ktstackSha256":"\(request.sha256)"}}
        """
    }

    func testResumableUploadSendsChunksAndVerifiesChecksum() async throws {
        let request = try upload()
        let session = "https://www.googleapis.com/upload/drive/v3/files?upload_id=S1"
        let (client, transport, _) = client([
            json(#"{"id":"ROOT1","name":"Backups"}"#),
            json(#"{"files":[{"id":"P1","name":"Shop"}]}"#),
            json("{}", headers: ["Location": session]),
            json("", status: 308, headers: ["Range": "bytes=0-9"]),
            json("", status: 308, headers: ["Range": "bytes=0-19"]),
            json(try uploadedFile(request))
        ])
        let reported = ProgressRecorder()
        let object = try await client.upload(request) { reported.record($0) }
        XCTAssertEqual(object.id, "F1")
        XCTAssertEqual(object.planID, request.planID)
        XCTAssertEqual(object.sha256, request.sha256)
        let ranges = transport.requests[3...5].map { $0.0.headers["Content-Range"] }
        XCTAssertEqual(ranges, ["bytes 0-9/25", "bytes 10-19/25", "bytes 20-24/25"])
        XCTAssertEqual(reported.values.last, 1)
        let start = transport.requests[2]
        XCTAssertEqual(start.0.headers["X-Upload-Content-Length"], "25")
        XCTAssertEqual(start.0.headers["Authorization"], "Bearer tok")
        guard case let .data(metadata) = start.1 else { return XCTFail("missing metadata") }
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: metadata) as? [String: Any])
        XCTAssertEqual(parsed["parents"] as? [String], ["P1"])
        XCTAssertEqual((parsed["appProperties"] as? [String: String])?["ktstackPlan"], request.planID.uuidString)
    }

    func testUploadCreatesPlanFolderWhenMissing() async throws {
        let request = try upload(size: 5)
        let (client, transport, _) = client([
            json(#"{"id":"ROOT1","name":"Backups"}"#),
            json(#"{"files":[]}"#),
            json(#"{"id":"P2","name":"Shop"}"#),
            json("{}", headers: ["Location": "https://upload.example/s"]),
            json(try uploadedFile(request))
        ])
        _ = try await client.upload(request) { _ in }
        XCTAssertEqual(transport.requests[2].0.method, "POST")
        guard case let .data(body) = transport.requests[2].1 else { return XCTFail("missing body") }
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(parsed["parents"] as? [String], ["ROOT1"])
        XCTAssertEqual(parsed["mimeType"] as? String, DriveQuery.folderMimeType)
    }

    func testChunkFailureResumesFromQueriedOffset() async throws {
        let request = try upload(size: 15)
        let (client, transport, _) = client([
            json(#"{"id":"ROOT1","name":"Backups"}"#),
            json(#"{"files":[{"id":"P1","name":"Shop"}]}"#),
            json("{}", headers: ["Location": "https://upload.example/s"]),
            json("", status: 503),
            json("", status: 308, headers: ["Range": "bytes=0-9"]),
            json(try uploadedFile(request))
        ])
        _ = try await client.upload(request) { _ in }
        XCTAssertEqual(transport.requests[4].0.headers["Content-Range"], "bytes */15")
        XCTAssertEqual(transport.requests[5].0.headers["Content-Range"], "bytes 10-14/15")
    }

    func testMD5MismatchFailsVerification() async throws {
        let request = try upload(size: 5)
        let (client, _, _) = client([
            json(#"{"id":"ROOT1","name":"Backups"}"#),
            json(#"{"files":[{"id":"P1","name":"Shop"}]}"#),
            json("{}", headers: ["Location": "https://upload.example/s"]),
            json(try uploadedFile(request, md5: "0000"))
        ])
        do {
            _ = try await client.upload(request) { _ in }
            XCTFail("expected verification failure")
        } catch let error as BackupDestinationError {
            guard case .verificationFailed = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testUnauthorizedRefreshesTokenOnceAndRetries() async throws {
        let (client, transport, tokenTransport) = client([
            json(#"{"error":{"code":401,"message":"Invalid Credentials"}}"#, status: 401),
            json(#"{"user":{"emailAddress":"dev@example.com"}}"#)
        ])
        let email = try await client.accountEmail()
        XCTAssertEqual(email, "dev@example.com")
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(tokenTransport.requests.count, 2)
    }

    func testRateLimitIsRetriedWithBackoff() async throws {
        let limited = #"{"error":{"code":403,"message":"Rate","errors":[{"reason":"userRateLimitExceeded"}]}}"#
        let (client, transport, _) = client([
            json(limited, status: 403),
            json("", status: 500),
            json(#"{"user":{"emailAddress":"dev@example.com"}}"#)
        ])
        _ = try await client.accountEmail()
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertTrue(GoogleDriveClient.isRetryable(HTTPResponse(status: 403, body: Data(limited.utf8))))
        XCTAssertFalse(GoogleDriveClient.isRetryable(HTTPResponse(status: 403, body: Data(#"{"error":{"code":403}}"#.utf8))))
    }

    func testTrashedOrMissingFolderIsReportedAsGone() async throws {
        let (trashed, _, _) = client([
            json(#"{"user":{"emailAddress":"a@b.c"}}"#),
            json(#"{"id":"ROOT1","name":"Backups","trashed":true}"#)
        ])
        let (missing, _, _) = client([
            json(#"{"user":{"emailAddress":"a@b.c"}}"#),
            json(#"{"error":{"code":404,"message":"File not found"}}"#, status: 404)
        ])
        for client in [trashed, missing] {
            do {
                _ = try await client.testConnection()
                XCTFail("expected folder gone")
            } catch {
                XCTAssertEqual(error as? BackupDestinationError, GoogleDriveClient.folderGone)
            }
        }
    }

    func testListOwnedPagesAndQueriesAppProperties() async throws {
        let planID = UUID()
        let first = """
        {"nextPageToken":"N2","files":[{"id":"A","name":"ktstack-x-20260510-020000.ktbackup","size":"10",
         "appProperties":{"ktstackPlan":"\(planID.uuidString)","ktstackSha256":"aa"}}]}
        """
        let (client, transport, _) = client([json(first), json(#"{"files":[{"id":"B","name":"b.ktbackup","size":"4"}]}"#)])
        let objects = try await client.list(ownedBy: planID)
        XCTAssertEqual(objects.map(\.id), ["A", "B"])
        XCTAssertEqual(objects[0].createdAt, date("2026-05-10 02:00:00"))
        let query = try XCTUnwrap(URLComponents(url: transport.requests[0].0.url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "q" }?.value,
                       "appProperties has { key='ktstackPlan' and value='\(planID.uuidString)' } and trashed = false")
        XCTAssertTrue(transport.requests[1].0.url.query?.contains("pageToken=N2") == true)
    }

    func testMoveToTrashPatchesTrashedFlag() async throws {
        let (client, transport, _) = client([json(#"{"id":"A","name":"a","trashed":true}"#)])
        let outcome = try await client.moveToTrash(RemoteBackupObject(id: "A", name: "a", sizeBytes: 1, createdAt: nil, planID: nil, sha256: nil))
        XCTAssertEqual(outcome, .trashed)
        XCTAssertEqual(transport.requests[0].0.method, "PATCH")
        XCTAssertEqual(transport.requests[0].1, .data(Data(#"{"trashed":true}"#.utf8)))
    }

    func testQueryLiteralEscapesQuotes() {
        XCTAssertEqual(DriveQuery.literal("O'Brien\\x"), #"'O\'Brien\\x'"#)
        XCTAssertEqual(GoogleDriveClient.nextOffset("bytes=0-1048575"), 1_048_576)
        XCTAssertEqual(GoogleDriveClient.nextOffset(nil), 0)
    }
}
