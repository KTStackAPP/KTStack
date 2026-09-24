import Foundation

public struct GlobalCLILink: Sendable {
    public enum State: Sendable, Equatable {
        case absent
        case managed
        case foreign
    }

    public enum LinkError: LocalizedError {
        case sourceMissing(String)
        case foreignFile(String)
        case notWritable(path: String, target: String)
        public var errorDescription: String? {
            switch self {
            case let .sourceMissing(path):
                "The kt command was not found at \(path)."
            case let .foreignFile(path):
                "\(path) already exists and was not installed by KTStack. Remove or rename it, then try again."
            case let .notWritable(path, target):
                "Cannot write to \(path). Run this in Terminal instead: sudo ln -s \"\(target)\" \"\(path)\""
            }
        }
    }

    public static let defaultPath = URL(fileURLWithPath: "/usr/local/bin/kt")

    public let link: URL

    public init(link: URL = GlobalCLILink.defaultPath) {
        self.link = link
    }

    public func state() -> State {
        let fm = FileManager.default
        if let destination = try? fm.destinationOfSymbolicLink(atPath: link.path) {
            return Self.isManagedDestination(destination) ? .managed : .foreign
        }
        return (try? fm.attributesOfItem(atPath: link.path)) == nil ? .absent : .foreign
    }

    public func install(target: URL) throws {
        let fm = FileManager.default
        switch state() {
        case .foreign:
            throw LinkError.foreignFile(link.path)
        case .managed:
            try replace(target) { try fm.removeItem(at: link) }
        case .absent:
            break
        }
        try replace(target) { try fm.createSymbolicLink(atPath: link.path, withDestinationPath: target.path) }
    }

    public func removeIfManaged() {
        guard state() == .managed else { return }
        try? FileManager.default.removeItem(at: link)
    }

    static func isManagedDestination(_ destination: String) -> Bool {
        let appBinary = destination.hasSuffix(".app/Contents/MacOS/kt")
        return appBinary && destination.range(of: "KTStack", options: .caseInsensitive) != nil
    }

    private func replace(_ target: URL, _ body: () throws -> Void) throws {
        do {
            try body()
        } catch let error as CocoaError where error.code == .fileWriteNoPermission
            || error.code == .fileWriteVolumeReadOnly {
            throw LinkError.notWritable(path: link.path, target: target.path)
        } catch let error as POSIXError where error.code == .EACCES || error.code == .EPERM {
            throw LinkError.notWritable(path: link.path, target: target.path)
        }
    }
}
