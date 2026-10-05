import Foundation

public struct GoogleOAuthClient: Equatable, Sendable {
    public static let bundledClientIDKey = "KTGoogleOAuthClientID"
    public static let bundledClientSecretKey = "KTGoogleOAuthClientSecret"
    public static let bundledPickerAPIKey = "KTGooglePickerAPIKey"
    public static let bundledProjectNumberKey = "KTGoogleProjectNumber"
    public static let driveScope = "https://www.googleapis.com/auth/drive.file"
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let revocationEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!

    public var clientID: String
    public var clientSecret: String?

    public init(clientID: String, clientSecret: String?) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    public static func bundled(_ info: [String: Any]?) -> GoogleOAuthClient? {
        guard let clientID = info?[bundledClientIDKey] as? String, !clientID.isEmpty, !clientID.hasPrefix("$(") else {
            return nil
        }
        let secret = (info?[bundledClientSecretKey] as? String).flatMap { $0.isEmpty || $0.hasPrefix("$(") ? nil : $0 }
        return GoogleOAuthClient(clientID: clientID, clientSecret: secret)
    }
}

public struct PKCEPair: Equatable, Sendable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = Self.base64URL(Data(SigV4SHA.sha256(Data(verifier.utf8))))
    }

    public static func random() -> PKCEPair {
        PKCEPair(verifier: randomToken(byteCount: 48))
    }

    public static func randomToken(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
