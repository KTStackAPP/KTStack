import Foundation
import MongoKitten

struct MongoLossyField: Equatable, Sendable {
    let path: String
    let typeName: String
}

enum MongoLossyFieldScanner {
    private static let deprecatedTypeNames: [UInt8: String] = [0x06: "undefined", 0x0C: "DBPointer", 0x0E: "symbol"]

    static func scan(_ document: Document, prefix: String = "") -> [MongoLossyField] {
        MongoRawBSON.fields(of: document).flatMap { field -> [MongoLossyField] in
            let path = prefix.isEmpty ? field.key : "\(prefix).\(field.key)"
            if let name = deprecatedTypeNames[field.type] { return [MongoLossyField(path: path, typeName: name)] }
            guard field.type == 0x03 || field.type == 0x04 else { return [] }
            return scan(Document(bytes: Array(field.value)), prefix: path)
        }
    }
}
