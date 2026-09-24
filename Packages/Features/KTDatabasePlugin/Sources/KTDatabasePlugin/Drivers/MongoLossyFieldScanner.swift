import Foundation
import MongoKitten

struct MongoLossyField: Equatable, Sendable {
    let path: String
    let typeName: String
}

enum MongoLossyFieldScanner {
    static func scan(_ document: Document, prefix: String = "") -> [MongoLossyField] {
        var found: [MongoLossyField] = []
        for (key, value) in document {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? Document {
                found += scan(nested, prefix: path)
            } else if let typeName = lossyTypeName(value) {
                found.append(MongoLossyField(path: path, typeName: typeName))
            }
        }
        return found
    }

    static func lossyTypeName(_ value: Primitive) -> String? {
        switch value {
        case is Decimal128: return "Decimal128"
        case is RegularExpression: return "regular expression"
        case is JavaScriptCode, is JavaScriptCodeWithScope: return "JavaScript code"
        case let binary as Binary:
            if case .generic = binary.subType { return nil }
            return "binary (non-generic subtype)"
        default: return nil
        }
    }
}
