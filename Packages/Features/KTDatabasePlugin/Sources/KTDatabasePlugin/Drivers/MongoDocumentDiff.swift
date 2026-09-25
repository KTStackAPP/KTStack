import Foundation
import MongoKitten

struct MongoUpdatePlan {
    var set: [(path: String, element: MongoRawBSON.Element)] = []
    var unset: [String] = []

    func element(at path: String) -> MongoRawBSON.Element? {
        set.first { $0.path == path }?.element
    }

    var updateDocument: Document? {
        var update = Document()
        if !set.isEmpty { update["$set"] = MongoRawBSON.document(set.map { ($0.path, $0.element) }, isArray: false) }
        if !unset.isEmpty {
            var removed = Document()
            for path in unset { removed[path] = "" }
            update["$unset"] = removed
        }
        return update.keys.isEmpty ? nil : update
    }
}

enum MongoDocumentDiff {
    static func plan(original: Document, editedJSON: String) throws -> MongoUpdatePlan {
        let parsed = try JSONSerialization.jsonObject(with: Data(editedJSON.utf8), options: [.fragmentsAllowed])
        guard let edited = parsed as? [String: Any] else {
            throw DatabaseError.syntax("A document must be a JSON object.")
        }
        if let field = MongoLossyFieldScanner.scan(original).first { throw refusal(field.path, field.typeName) }
        var plan = MongoUpdatePlan()
        try diff(original: original, edited: edited, prefix: "", into: &plan)
        return plan
    }

    private static func diff(
        original: Document,
        edited: [String: Any],
        prefix: String,
        into plan: inout MongoUpdatePlan
    ) throws {
        let originalJSON = MongoJSONMapper.jsonObject(from: original) as? [String: Any] ?? [:]
        for key in original.keys where edited[key] == nil && !(prefix.isEmpty && key == "_id") {
            plan.unset.append(path(prefix, key))
        }
        for key in edited.keys.sorted() where !(prefix.isEmpty && key == "_id") {
            guard let newValue = edited[key] else { continue }
            let fieldPath = path(prefix, key)
            guard let old = original[key], let oldJSON = originalJSON[key] else {
                plan.set.append((fieldPath, try MongoJSONMapper.element(from: newValue)))
                continue
            }
            if sameJSON(oldJSON, newValue) { continue }
            if let oldDocument = old as? Document, !oldDocument.isArray,
               let newDictionary = newValue as? [String: Any],
               !MongoJSONMapper.isWrapper(newDictionary)
            {
                try diff(original: oldDocument, edited: newDictionary, prefix: fieldPath, into: &plan)
                continue
            }
            plan.set.append((fieldPath, try MongoTypePreserver.element(newValue, keepingTypeOf: old)))
        }
    }

    private static func refusal(_ path: String, _ typeName: String) -> DatabaseError {
        .syntax("“\(path)” holds a deprecated \(typeName) value that the editor can't show or write back. "
            + "Edit this document with mongosh or MongoDB Compass.")
    }

    private static func path(_ prefix: String, _ key: String) -> String {
        prefix.isEmpty ? key : "\(prefix).\(key)"
    }

    static func sameJSON(_ lhs: Any, _ rhs: Any) -> Bool {
        let options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .sortedKeys]
        guard let left = try? JSONSerialization.data(withJSONObject: lhs, options: options),
              let right = try? JSONSerialization.data(withJSONObject: rhs, options: options)
        else { return false }
        return left == right
    }
}
