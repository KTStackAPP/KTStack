import Foundation

public indirect enum DumpNode: Sendable {
    case scalar(String)
    case array([(key: String, value: DumpNode)])
    case object(className: String, properties: [(key: String, value: DumpNode)])
    case reference(Int)

    public var displaySummary: String {
        switch self {
        case .scalar(let s):          return s
        case .array(let items):       return "array(\(items.count))"
        case .object(let cls, _):     return cls
        case .reference(let n):       return "&\(n)"
        }
    }
}
