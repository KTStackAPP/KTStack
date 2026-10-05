import CryptoKit
import Foundation

public enum FileDigest {
    static let chunkSize = 1 << 20

    public static func sha256Hex(of url: URL) throws -> String {
        var hasher = SHA256()
        try stream(url) { hasher.update(data: $0) }
        return hex(hasher.finalize())
    }

    public static func md5Hex(of url: URL) throws -> String {
        var hasher = Insecure.MD5()
        try stream(url) { hasher.update(data: $0) }
        return hex(hasher.finalize())
    }

    public static func size(of url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func stream(_ url: URL, _ consume: (Data) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            consume(chunk)
        }
    }
}
