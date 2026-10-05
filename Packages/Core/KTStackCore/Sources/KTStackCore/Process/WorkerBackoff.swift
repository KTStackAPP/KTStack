import Foundation

public struct WorkerBackoff: Sendable, Equatable {
    public enum Decision: Sendable, Equatable {
        case restart(after: TimeInterval)
        case giveUp
    }

    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let stableRuntime: TimeInterval
    public let maxQuickExits: Int
    public private(set) var quickExits = 0

    public init(
        initialDelay: TimeInterval = 1,
        maxDelay: TimeInterval = 60,
        stableRuntime: TimeInterval = 60,
        maxQuickExits: Int = 8
    ) {
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.stableRuntime = stableRuntime
        self.maxQuickExits = maxQuickExits
    }

    public mutating func record(runtime: TimeInterval) -> Decision {
        guard runtime < stableRuntime else {
            quickExits = 0
            return .restart(after: initialDelay)
        }
        quickExits += 1
        guard quickExits < maxQuickExits else { return .giveUp }
        let exponent = Double(quickExits - 1)
        return .restart(after: min(maxDelay, initialDelay * pow(2, exponent)))
    }
}
