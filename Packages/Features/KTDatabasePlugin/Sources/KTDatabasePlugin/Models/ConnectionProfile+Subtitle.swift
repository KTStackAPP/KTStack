import Foundation

public extension ConnectionProfile {
    func displayTitle(lastUsedDatabase: String? = nil) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty, trimmedName != trimmedHost {
            return trimmedName
        }
        if kind == .sqlite, let path = filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        let trimmedDB = database.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDB.isEmpty {
            return trimmedDB
        }
        if Self.isLoopback(host) {
            return "Local \(kindDisplay)"
        }
        return !trimmedHost.isEmpty ? trimmedHost : defaultEngineName
    }

    func displaySubtitle(lastUsedDatabase: String? = nil) -> String {
        if kind == .sqlite, let path = filePath, !path.isEmpty {
            return path
        }
        let engine = kindDisplay
        let endpoint = "\(host):\(port)"
        let trimmedDB = database.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDB.isEmpty {
            if displayTitle(lastUsedDatabase: lastUsedDatabase) == trimmedDB {
                return "\(engine) · \(endpoint)"
            }
            return "\(engine) · \(trimmedDB) · \(endpoint)"
        }
        if let last = lastUsedDatabase?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return "\(engine) · \(endpoint) · Last: \(last)"
        }
        return "\(engine) · \(endpoint)"
    }

    func resolvedDatabase(lastUsedDatabase: String? = nil) -> String? {
        let trimmedDB = database.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDB.isEmpty {
            return trimmedDB
        }
        if let last = lastUsedDatabase?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return last
        }
        return nil
    }

    var defaultEngineName: String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }

    var kindDisplay: String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }

    var subtitle: String {
        displaySubtitle()
    }
}
