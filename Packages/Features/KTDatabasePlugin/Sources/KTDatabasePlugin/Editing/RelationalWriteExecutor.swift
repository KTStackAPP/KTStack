import Foundation

/// Runs planned writes through the phase-2 driver inside one transaction. The driver enforces the
/// per-step affected-row guard and rolls the whole batch back on any mismatch; a read-only
/// connection is refused before anything runs.
public struct RelationalWriteExecutor {
    public let driver: any RelationalDriver
    public let database: String

    public init(driver: any RelationalDriver, database: String) {
        self.driver = driver
        self.database = database
    }

    public func commit(_ steps: [WriteStep]) async throws {
        guard !steps.isEmpty else { return }
        guard driver.capabilities.canEditRows else {
            throw DatabaseError.connection("This connection is read-only.")
        }
        try await driver.executeTransaction(steps, database: database)
    }
}
