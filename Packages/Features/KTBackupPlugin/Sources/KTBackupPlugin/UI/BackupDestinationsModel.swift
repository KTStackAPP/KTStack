import AppKit
import Combine
import Foundation

@MainActor
final class BackupDestinationsModel: ObservableObject {
    @Published private(set) var testing: Set<UUID> = []

    let services: BackupServices
    let scheduler: BackupScheduler

    init(services: BackupServices, scheduler: BackupScheduler) {
        self.services = services
        self.scheduler = scheduler
    }

    var destinations: [BackupDestination] {
        scheduler.state.destinations
    }

    var googleAvailable: Bool {
        services.factory.bundledGoogleClient != nil
    }

    var pickerAvailable: Bool {
        services.picker != nil
    }

    func plans(using id: UUID) -> [BackupPlan] {
        scheduler.state.plans.filter { $0.destinationID == id }
    }

    func save(_ destination: BackupDestination, secrets updates: [BackupSecretKind: String]) throws {
        for (kind, value) in updates {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try services.secrets.deleteSecret(kind, for: destination.id)
            } else {
                try services.secrets.setSecret(trimmed, kind, for: destination.id)
            }
        }
        services.factory.forgetSession(for: destination.id)
        try scheduler.update { state in
            if let index = state.destinations.firstIndex(where: { $0.id == destination.id }) {
                state.destinations[index] = destination
            } else {
                state.destinations.append(destination)
            }
        }
    }

    func discardDraft(_ id: UUID) {
        guard scheduler.state.destination(id) == nil else { return }
        services.secrets.deleteAllSecrets(for: id)
        services.factory.forgetSession(for: id)
    }

    func remove(_ destination: BackupDestination, reassignTo replacement: UUID?) async throws {
        if destination.kind == .googleDrive { await services.factory.revokeGoogle(for: destination) }
        try scheduler.update { state in
            state.destinations.removeAll { $0.id == destination.id }
            for index in state.plans.indices where state.plans[index].destinationID == destination.id {
                state.plans[index].destinationID = replacement
                if replacement == nil { state.plans[index].isEnabled = false }
            }
        }
        services.secrets.deleteAllSecrets(for: destination.id)
        services.factory.forgetSession(for: destination.id)
    }

    func hasSecret(_ kind: BackupSecretKind, for id: UUID) -> Bool {
        ((try? services.secrets.secret(kind, for: id)) ?? nil)?.isEmpty == false
    }

    @discardableResult
    func test(_ destination: BackupDestination, secrets overrides: [BackupSecretKind: String] = [:]) async -> DestinationTestResult {
        testing.insert(destination.id)
        defer { testing.remove(destination.id) }
        let result: DestinationTestResult
        do {
            let message = try await client(for: destination, secrets: overrides).testConnection()
            result = DestinationTestResult(testedAt: Date(), succeeded: true, message: message)
        } catch {
            result = DestinationTestResult(testedAt: Date(), succeeded: false, message: error.localizedDescription)
        }
        try? scheduler.update { state in
            if let index = state.destinations.firstIndex(where: { $0.id == destination.id }) {
                state.destinations[index].lastTest = result
            }
        }
        return result
    }

    func client(for destination: BackupDestination, secrets overrides: [BackupSecretKind: String] = [:]) throws
        -> any BackupDestinationClient {
        if overrides.isEmpty { return try services.factory.client(for: destination) }
        return try services.factory.draftClient(for: destination, secrets: overrides)
    }

    func connectGoogle(_ destination: BackupDestination) async throws -> String {
        services.factory.forgetSession(for: destination.id)
        let flow = try services.factory.signInFlow(for: destination, openURL: Self.open)
        let result = try await flow.run()
        try services.secrets.setSecret(result.refreshToken, .googleRefreshToken, for: destination.id)
        services.factory.forgetSession(for: destination.id)
        return result.accountEmail
    }

    func disconnectGoogle(_ destination: BackupDestination) async {
        await services.factory.revokeGoogle(for: destination)
        try? services.secrets.deleteSecret(.googleRefreshToken, for: destination.id)
        services.factory.forgetSession(for: destination.id)
    }

    func pickGoogleFolder(_ destination: BackupDestination) async throws -> RemoteFolder? {
        guard let picker = services.picker else { return nil }
        let token = try await services.factory.tokenProvider(for: destination).accessToken()
        return try await GooglePickerFlow(configuration: picker, accessToken: token, openURL: Self.open).run()
    }

    nonisolated static func open(_ url: URL) {
        DispatchQueue.main.async { NSWorkspace.shared.open(url) }
    }
}
