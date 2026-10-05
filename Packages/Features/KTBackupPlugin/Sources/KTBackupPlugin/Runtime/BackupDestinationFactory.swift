import Foundation

public final class BackupDestinationFactory: BackupDestinationClientMaking, @unchecked Sendable {
    let paths: BackupPaths
    let secrets: any BackupSecretStoring
    let transport: any HTTPTransport
    public let bundledGoogleClient: GoogleOAuthClient?
    private let lock = NSLock()
    private var providers: [UUID: (client: GoogleOAuthClient, provider: GoogleAccessTokenProvider)] = [:]

    public init(paths: BackupPaths, secrets: any BackupSecretStoring, transport: any HTTPTransport,
                bundledGoogleClient: GoogleOAuthClient?) {
        self.paths = paths
        self.secrets = secrets
        self.transport = transport
        self.bundledGoogleClient = bundledGoogleClient
    }

    public func client(for destination: BackupDestination?) throws -> any BackupDestinationClient {
        guard let destination else { return localArchivesClient() }
        switch destination.kind {
        case .local:
            guard let path = destination.local?.path, !path.isEmpty else {
                throw BackupDestinationError.notConfigured("choose a folder.")
            }
            return LocalFolderClient(folder: URL(fileURLWithPath: path, isDirectory: true))
        case .s3:
            guard let settings = destination.s3 else { throw BackupDestinationError.notConfigured("enter the S3 bucket details.") }
            guard let secret = try secrets.secret(.s3SecretAccessKey, for: destination.id), !secret.isEmpty else {
                throw BackupDestinationError.missingCredentials("the S3 secret access key isn't saved in the Keychain.")
            }
            return S3Client(configuration: try S3Configuration(settings: settings, secretAccessKey: secret), transport: transport)
        case .googleDrive:
            let settings = destination.googleDrive ?? GoogleDriveSettings()
            return GoogleDriveClient(folderID: settings.folderID, tokens: try tokenProvider(for: destination), transport: transport)
        }
    }

    public func draftClient(for destination: BackupDestination, secrets overrides: [BackupSecretKind: String]) throws
        -> any BackupDestinationClient {
        let overlay = OverlaySecretStore(base: secrets, destinationID: destination.id, overrides: overrides)
        return try BackupDestinationFactory(paths: paths, secrets: overlay, transport: transport, bundledGoogleClient: bundledGoogleClient)
            .client(for: destination)
    }

    public func localArchivesClient() -> any BackupDestinationClient {
        LocalFolderClient(folder: paths.archives)
    }

    public func googleOAuthClient(for destination: BackupDestination) throws -> GoogleOAuthClient {
        if let custom = destination.googleDrive?.customClientID?.trimmingCharacters(in: .whitespaces), !custom.isEmpty {
            let secret = try secrets.secret(.googleClientSecret, for: destination.id)
            return GoogleOAuthClient(clientID: custom, clientSecret: secret?.isEmpty == false ? secret : nil)
        }
        guard let bundledGoogleClient else { throw GoogleAuthError.clientMissing }
        return bundledGoogleClient
    }

    public func tokenProvider(for destination: BackupDestination) throws -> GoogleAccessTokenProvider {
        let oauth = try googleOAuthClient(for: destination)
        lock.lock()
        defer { lock.unlock() }
        if let cached = providers[destination.id], cached.client == oauth { return cached.provider }
        let id = destination.id
        let secrets = secrets
        let provider = GoogleAccessTokenProvider(
            tokenClient: GoogleTokenClient(client: oauth, transport: transport),
            loadRefreshToken: { try secrets.secret(.googleRefreshToken, for: id) }
        )
        providers[id] = (oauth, provider)
        return provider
    }

    public func forgetSession(for destinationID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        providers[destinationID] = nil
    }

    public func signInFlow(for destination: BackupDestination, openURL: @escaping @Sendable (URL) -> Void) throws -> GoogleSignInFlow {
        GoogleSignInFlow(client: try googleOAuthClient(for: destination), transport: transport, openURL: openURL)
    }

    public func revokeGoogle(for destination: BackupDestination) async {
        guard let token = try? secrets.secret(.googleRefreshToken, for: destination.id),
              let oauth = try? googleOAuthClient(for: destination) else { return }
        await GoogleTokenClient(client: oauth, transport: transport).revoke(token)
    }
}
