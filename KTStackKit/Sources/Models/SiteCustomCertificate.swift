import Foundation

// Cert người dùng import; bản copy nằm ở config/certs-custom/<uuid>/, source path chỉ để Re-import.
public struct SiteCustomCertificate: Codable, Hashable, Sendable {
    public var sourceCertPath: String
    public var sourceKeyPath: String
    public var notAfter: Date
    public var names: [String]

    public init(sourceCertPath: String, sourceKeyPath: String, notAfter: Date, names: [String]) {
        self.sourceCertPath = sourceCertPath
        self.sourceKeyPath = sourceKeyPath
        self.notAfter = notAfter
        self.names = names
    }
}
