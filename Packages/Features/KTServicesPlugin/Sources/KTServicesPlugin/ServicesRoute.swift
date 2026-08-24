import Foundation

public enum ServicesRoute: Sendable {
    case runtimes
    case settings
    case logs(sourceID: String?)
}
