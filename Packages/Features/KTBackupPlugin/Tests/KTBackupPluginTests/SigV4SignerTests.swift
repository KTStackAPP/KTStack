import Foundation
import XCTest
@testable import KTBackupPlugin

final class SigV4SignerTests: XCTestCase {
    private let suiteSigner = SigV4Signer(
        credentials: SigV4Credentials(accessKeyID: "AKIDEXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"),
        region: "us-east-1",
        service: "service",
        includesContentHashHeader: false
    )
    private let suiteDate = date("2015-08-30 12:36:00")
    private let s3Signer = SigV4Signer(
        credentials: SigV4Credentials(accessKeyID: "AKIAIOSFODNN7EXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"),
        region: "us-east-1"
    )
    private let s3Date = date("2013-05-24 00:00:00")

    private func signature(_ request: HTTPRequestSpec) -> String? {
        request.headers["Authorization"]?.components(separatedBy: "Signature=").last
    }

    private func suiteRequest(_ path: String) -> HTTPRequestSpec {
        HTTPRequestSpec(method: "GET", url: URL(string: "https://example.amazonaws.com\(path)")!)
    }

    func testGetVanilla() {
        let signed = suiteSigner.signed(suiteRequest("/"), payloadHash: SigV4Signer.emptyPayloadHash, date: suiteDate)
        XCTAssertEqual(
            signed.headers["Authorization"],
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, "
                + "SignedHeaders=host;x-amz-date, Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31"
        )
    }

    func testGetVanillaQueryOrderKey() {
        let signed = suiteSigner.signed(suiteRequest("/?Param2=value2&Param1=value1"), payloadHash: SigV4Signer.emptyPayloadHash, date: suiteDate)
        XCTAssertEqual(signature(signed), "b97d918cfa904a5beff61c982a1b6f458b799221646efd99d3219ec94cdf2500")
    }

    func testGetUnreservedCharacters() {
        let path = "/-._~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        let signed = suiteSigner.signed(suiteRequest(path), payloadHash: SigV4Signer.emptyPayloadHash, date: suiteDate)
        XCTAssertEqual(signature(signed), "07ef7494c76fa4850883e2b006601f940f8a34d404d0cfa977f52a65bbf5f24f")
    }

    func testS3GetObjectExample() {
        let request = HTTPRequestSpec(method: "GET", url: URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")!,
                                      headers: ["Range": "bytes=0-9"])
        let signed = s3Signer.signed(request, payloadHash: SigV4Signer.emptyPayloadHash, date: s3Date)
        XCTAssertEqual(
            signed.headers["Authorization"],
            "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, "
                + "SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, "
                + "Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
        )
    }

    func testS3PutObjectExample() {
        let body = Data("Welcome to Amazon S3.".utf8)
        let request = HTTPRequestSpec(method: "PUT", url: URL(string: "https://examplebucket.s3.amazonaws.com/test$file.text")!,
                                      headers: ["Date": "Fri, 24 May 2013 00:00:00 GMT", "x-amz-storage-class": "REDUCED_REDUNDANCY"])
        let signed = s3Signer.signed(request, payloadHash: SigV4Signer.sha256Hex(body), date: s3Date)
        XCTAssertEqual(SigV4Signer.sha256Hex(body), "44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072")
        XCTAssertEqual(signature(signed), "98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd")
    }

    func testS3ListObjectsExample() {
        let request = HTTPRequestSpec(method: "GET", url: URL(string: "https://examplebucket.s3.amazonaws.com/?max-keys=2&prefix=J")!)
        let signed = s3Signer.signed(request, payloadHash: SigV4Signer.emptyPayloadHash, date: s3Date)
        XCTAssertEqual(signature(signed), "34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7")
    }

    func testS3BucketSubresourceWithoutValue() {
        let request = HTTPRequestSpec(method: "GET", url: URL(string: "https://examplebucket.s3.amazonaws.com/?lifecycle")!)
        let signed = s3Signer.signed(request, payloadHash: SigV4Signer.emptyPayloadHash, date: s3Date)
        XCTAssertEqual(signature(signed), "fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543")
    }

    func testUnsignedPayloadAndCustomPortHost() {
        let request = HTTPRequestSpec(method: "GET", url: URL(string: "http://127.0.0.1:9000/bucket/key")!)
        let signed = s3Signer.signed(request, payloadHash: SigV4Signer.unsignedPayload, date: s3Date)
        XCTAssertEqual(signed.headers["Host"], "127.0.0.1:9000")
        XCTAssertEqual(signed.headers["X-Amz-Content-Sha256"], "UNSIGNED-PAYLOAD")
    }
}
