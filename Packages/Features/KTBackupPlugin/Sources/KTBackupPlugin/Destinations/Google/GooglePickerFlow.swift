import Foundation

public struct GooglePickerConfiguration: Equatable, Sendable {
    public var apiKey: String
    public var appID: String

    public init(apiKey: String, appID: String) {
        self.apiKey = apiKey
        self.appID = appID
    }

    public static func bundled(_ info: [String: Any]?) -> GooglePickerConfiguration? {
        func value(_ key: String) -> String? {
            (info?[key] as? String).flatMap { $0.isEmpty || $0.hasPrefix("$(") ? nil : $0 }
        }
        guard let key = value(GoogleOAuthClient.bundledPickerAPIKey),
              let project = value(GoogleOAuthClient.bundledProjectNumberKey) else { return nil }
        return GooglePickerConfiguration(apiKey: key, appID: project)
    }
}

public struct GooglePickerFlow: Sendable {
    public static let port: UInt16 = 53_683

    let configuration: GooglePickerConfiguration
    let accessToken: String
    let openURL: @Sendable (URL) -> Void
    let timeout: TimeInterval

    public init(configuration: GooglePickerConfiguration, accessToken: String, timeout: TimeInterval = 600,
                openURL: @escaping @Sendable (URL) -> Void) {
        self.configuration = configuration
        self.accessToken = accessToken
        self.timeout = timeout
        self.openURL = openURL
    }

    public func run(port: UInt16 = GooglePickerFlow.port) async throws -> RemoteFolder? {
        let server = try LoopbackHTTPServer(port: port)
        defer { server.stop() }
        let nonce = PKCEPair.randomToken(byteCount: 24)
        openURL(URL(string: "http://127.0.0.1:\(server.port)/?n=\(nonce)")!)
        let deadline = Date().addingTimeInterval(timeout)
        var served = false
        while true {
            let incoming = try await server.nextRequest(timeout: deadline.timeIntervalSinceNow)
            guard incoming.queryItems["n"] == nonce else {
                incoming.respond(status: 404, body: "")
                continue
            }
            switch incoming.path {
            case "/" where !served:
                served = true
                incoming.respond(status: 200, body: GooglePickerPage.html(configuration: configuration, accessToken: accessToken, nonce: nonce))
            case "/picked":
                let items = incoming.queryItems
                guard let id = items["id"], !id.isEmpty else {
                    incoming.respond(status: 400, body: "")
                    continue
                }
                incoming.respond(status: 200, body: LoopbackPages.message("Folder selected", "You can close this tab and return to KTStack."))
                return RemoteFolder(id: id, name: items["name"] ?? id)
            case "/cancelled":
                incoming.respond(status: 200, body: LoopbackPages.message("No folder selected", "You can close this tab."))
                return nil
            default:
                incoming.respond(status: 404, body: "")
            }
        }
    }
}
