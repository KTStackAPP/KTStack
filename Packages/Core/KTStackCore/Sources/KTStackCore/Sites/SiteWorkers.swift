import Foundation

public enum SiteWorkerError: Equatable, Sendable, LocalizedError {
    case invalidName(String)
    case duplicateName(String)
    case invalidCommand(String)
    case tooMany(Int)

    public var errorDescription: String? {
        switch self {
        case let .invalidName(name):
            "“\(name)” is not a valid worker name. Use 1–\(SiteWorkers.maxNameLength) lowercase letters, digits or dashes."
        case let .duplicateName(name):
            "Another worker of this site is already named “\(name)”."
        case let .invalidCommand(name):
            "The command of “\(name)” is empty, too long or has an unclosed quote."
        case let .tooMany(limit):
            "A site can have at most \(limit) workers."
        }
    }
}

public enum SiteWorkers {
    public static let maxNameLength = 32
    public static let maxPerSite = 10

    public static func validate(_ workers: [SiteWorker]) -> SiteWorkerError? {
        guard workers.count <= maxPerSite else { return .tooMany(maxPerSite) }
        var seen = Set<String>()
        for worker in workers {
            guard isValidName(worker.name) else { return .invalidName(worker.name) }
            guard seen.insert(worker.name).inserted else { return .duplicateName(worker.name) }
            guard SiteWorkerCommand.arguments(worker.command) != nil else { return .invalidCommand(worker.name) }
        }
        return nil
    }

    public static func isValidName(_ name: String) -> Bool {
        guard (1...maxNameLength).contains(name.count), let first = name.unicodeScalars.first else { return false }
        guard isLowerAlphanumeric(first) else { return false }
        return name.unicodeScalars.allSatisfy { isLowerAlphanumeric($0) || $0 == "-" }
    }

    public static func suggestedName(_ base: String, existing: [SiteWorker]) -> String {
        let taken = Set(existing.map(\.name))
        guard taken.contains(base) else { return base }
        var index = 2
        while taken.contains("\(base)-\(index)") {
            index += 1
        }
        return "\(base)-\(index)"
    }

    private static func isLowerAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        (0x61...0x7A).contains(scalar.value) || (0x30...0x39).contains(scalar.value)
    }
}
