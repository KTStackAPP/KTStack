import Foundation
import KTPlatformContracts
@testable import KTBackupPlugin

func makeTemporaryDirectory(_ name: String = #function) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ktbackup-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func utcCalendar(_ identifier: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

func date(_ text: String, zone: String = "UTC") -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: zone)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: text)!
}

final class MemorySecretStore: BackupSecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func secret(_ kind: BackupSecretKind, for destinationID: UUID) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[Self.account(kind, destinationID)]
    }

    func setSecret(_ value: String, _ kind: BackupSecretKind, for destinationID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        values[Self.account(kind, destinationID)] = value
    }

    func deleteSecret(_ kind: BackupSecretKind, for destinationID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        values[Self.account(kind, destinationID)] = nil
    }
}

final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    typealias Responder = (HTTPRequestSpec, HTTPBody) throws -> HTTPResponse

    private let lock = NSLock()
    private var responders: [Responder]
    private(set) var requests: [(HTTPRequestSpec, HTTPBody)] = []

    init(_ responders: [Responder]) {
        self.responders = responders
    }

    func send(_ request: HTTPRequestSpec, body: HTTPBody, progress: BackupProgressHandler?) async throws -> HTTPResponse {
        let responder: Responder = try locked(lock) {
            requests.append((request, body))
            guard !responders.isEmpty else { throw BackupDestinationError.remote("Unexpected request \(request.method) \(request.url)") }
            return responders.removeFirst()
        }
        return try responder(request, body)
    }

    func download(_ request: HTTPRequestSpec, to fileURL: URL, progress: BackupProgressHandler?) async throws -> HTTPResponse {
        let response = try await send(request, body: .empty, progress: progress)
        if response.isSuccess {
            try response.body.write(to: fileURL)
        }
        return HTTPResponse(status: response.status, headers: response.headers)
    }

    var methods: [String] {
        locked(lock) { requests.map { "\($0.0.method) \($0.0.url.path)" } }
    }
}

struct FixedEnvironment: BackupRuntimeEnvironment {
    var running: Set<DatabaseEngine>
    var sites: [BackupSiteFolder] = []

    func runningEngines() async -> Set<DatabaseEngine> {
        running
    }

    func siteFolders(_ ids: [UUID]) async -> [BackupSiteFolder] {
        sites.filter { ids.contains($0.id) }
    }
}

func locked<T>(_ lock: NSLock, _ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
}

final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    func record(_ value: Double) {
        locked(lock) { recorded.append(value) }
    }

    var values: [Double] {
        locked(lock) { recorded }
    }
}
