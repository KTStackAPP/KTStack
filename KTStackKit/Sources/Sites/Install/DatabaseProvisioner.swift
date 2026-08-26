import Foundation

public struct DatabaseProvisioner: Sendable {
    public enum ProvisionError: LocalizedError, Equatable {
        case alreadyExists(String)
        public var errorDescription: String? {
            switch self {
            case let .alreadyExists(name):
                "A database named “\(name)” already exists — choose another name."
            }
        }
    }

    private let client: MySQLAdminClient
    private let ensureEngine: @Sendable () async throws -> Void

    public init(
        host: String = "127.0.0.1",
        port: Int = 3306,
        ensureEngine: @escaping @Sendable () async throws -> Void
    ) {
        client = MySQLAdminClient(host: host, port: port)
        self.ensureEngine = ensureEngine
    }

    public func exists(_ name: String) async throws -> Bool {
        try await ensureEngine()
        return try await client.databaseExists(name)
    }

    public func createDatabase(_ name: String) async throws {
        try await ensureEngine()
        if try await client.databaseExists(name) { throw ProvisionError.alreadyExists(name) }
        try await client.createDatabase(name)
    }

    public func dropDatabase(_ name: String) async throws {
        try await ensureEngine()
        try await client.dropDatabase(name)
    }
}
