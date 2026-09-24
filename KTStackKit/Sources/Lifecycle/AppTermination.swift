import Foundation

public enum AppTermination {
    public struct Refused: LocalizedError {
        public let label: String
        public var errorDescription: String? { "KTStack is quitting; not starting \(label)." }
    }

    private static let lock = NSLock()
    private static var terminating = false

    public static var isTerminating: Bool {
        lock.lock(); defer { lock.unlock() }
        return terminating
    }

    public static func begin() {
        lock.lock(); terminating = true; lock.unlock()
    }

    static func reset() {
        lock.lock(); terminating = false; lock.unlock()
    }
}
