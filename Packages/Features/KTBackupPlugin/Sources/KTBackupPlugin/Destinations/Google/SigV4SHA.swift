import CryptoKit
import Foundation

enum SigV4SHA {
    static func sha256(_ data: Data) -> [UInt8] {
        Array(SHA256.hash(data: data))
    }
}
