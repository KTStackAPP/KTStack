import Combine
import KTPlatformContracts
import SwiftUI

@MainActor
final class DumpsViewModel: ObservableObject {
    @Published private(set) var events: [DumpEvent] = []
    @Published var enabled = false
    @Published var autoScroll = true
    @Published var errorMessage: String?
    @Published private(set) var busy = false

    private let php: any PHPRuntimeConfiguring
    private let dumpServer: DumpServer
    private let injector: DumpInjector
    private var cancellable: AnyCancellable?
    private static let eventCap = 300

    init(php: any PHPRuntimeConfiguring, server: DumpServer, injector: DumpInjector) {
        self.php = php
        dumpServer = server
        self.injector = injector
        cancellable = dumpServer.eventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                events.append(event)
                if events.count > Self.eventCap {
                    events.removeFirst(events.count - Self.eventCap)
                }
            }
    }

    func toggle(_ on: Bool) {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        Task {
            do {
                if on { try await enable() } else { try await disable() }
                enabled = on
            } catch {
                errorMessage = error.localizedDescription
            }
            busy = false
        }
    }

    private func enable() async throws {
        let port = try await dumpServer.start()
        var enabledVersions: [String] = []
        do {
            for version in php.installedPHPVersions {
                try injector.enable(version: version, port: port)
                enabledVersions.append(version)
                try await php.reloadPHPPool(version: version)
            }
        } catch {
            for version in enabledVersions {
                try? injector.disable(version: version)
                try? await php.reloadPHPPool(version: version)
            }
            injector.cleanupPrependFile()
            dumpServer.stop()
            throw error
        }
    }

    private func disable() async throws {
        for version in php.installedPHPVersions {
            try injector.disable(version: version)
            try await php.reloadPHPPool(version: version)
        }
        injector.cleanupPrependFile()
        dumpServer.stop()
    }

    func clear() {
        events = []
    }
}
