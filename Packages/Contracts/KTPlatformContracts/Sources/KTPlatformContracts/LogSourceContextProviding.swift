import Foundation

// Ngữ cảnh platform mà Logs cần để liệt kê log source; platform conform trong KTStackKit.
public protocol LogSourceContextProviding: AnyObject {
    @MainActor var siteDomains: [String] { get }
    @MainActor var phpVersions: [String] { get }
}
