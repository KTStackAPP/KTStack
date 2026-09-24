import Foundation
import KTPlatformContracts

@MainActor
public final class DatabaseAdminModel: ObservableObject {
    public enum Connection: Equatable {
        case idle
        case connecting
        case connected
        case failed(DatabaseError)
    }

    @Published public private(set) var connection: Connection = .idle
    @Published public private(set) var selectedProfile: ConnectionProfile?
    @Published public internal(set) var backupStatus: BackupStatus = .idle

    let tools: any DatabaseToolsProviding
    let passwordFor: @Sendable (ConnectionProfile) -> String?
    let dumpService: DumpService
    private let makeDriver: RelationalDriverFactory
    private(set) var driver: RelationalDriver?
    private var generation = 0

    public init(
        tools: any DatabaseToolsProviding,
        makeDriver: RelationalDriverFactory? = nil,
        passwordFor: @escaping @Sendable (ConnectionProfile) -> String? = RelationalDrivers.password,
        dumpService: DumpService? = nil
    ) {
        self.tools = tools
        self.makeDriver = makeDriver ?? RelationalDrivers.factory(tools: tools)
        self.passwordFor = passwordFor
        self.dumpService = dumpService ?? DumpService(tools: tools)
    }

    public var isReadOnlyConnection: Bool {
        selectedProfile?.readOnly ?? false
    }

    public func select(profile: ConnectionProfile) async {
        generation += 1
        let token = generation
        let previous = driver
        driver = nil
        selectedProfile = profile
        connection = .connecting
        await previous?.closeSession()
        guard let next = makeDriver(profile, passwordFor(profile)) else {
            connection = .failed(.connection("Unsupported engine: \(profile.kind.rawValue)"))
            return
        }
        driver = next
        do {
            try await next.ping()
            guard token == generation else { return }
            connection = .connected
        } catch {
            guard token == generation else { return }
            connection = .failed(Self.asDatabaseError(error))
        }
    }

    public func close() async {
        generation += 1
        let previous = driver
        driver = nil
        selectedProfile = nil
        connection = .idle
        backupStatus = .idle
        await previous?.closeSession()
    }

    @discardableResult
    public func createDatabase(named name: String) async -> Bool {
        guard let profile = selectedProfile else { return false }
        guard !isReadOnlyConnection else {
            backupStatus = .failed("This connection is read-only; creating databases is disabled.")
            return false
        }
        let database = name.trimmingCharacters(in: .whitespacesAndNewlines)
        backupStatus = .running("Creating \(database)…")
        do {
            switch profile.kind {
            case .mysql:
                try await dumpService.createDatabase(profile: profile, password: passwordFor(profile), database: database)
            case .postgres:
                try await PostgresBackupProvider(tools: tools).createDatabase(
                    profile: profile, password: passwordFor(profile), database: database
                )
            case .sqlite, .mongodb:
                throw DatabaseError.connection("Create Database isn't available for \(profile.kind.rawValue).")
            }
            backupStatus = .done("Created \(database).")
            return true
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
            return false
        }
    }

    static func asDatabaseError(_ error: Error) -> DatabaseError {
        (error as? DatabaseError) ?? .connection(error.localizedDescription)
    }
}
