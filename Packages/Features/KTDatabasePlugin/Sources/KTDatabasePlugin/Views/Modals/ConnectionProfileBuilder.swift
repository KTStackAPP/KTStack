import Foundation

struct ConnectionProfileBuilder {
    static func isValid(kind: DatabaseKind, host: String, port: String, user: String, filePath: String) -> Bool {
        if kind == .sqlite {
            return !filePath.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let portValid = Int(port).map { (1...65535).contains($0) } ?? false
        let hostValid = !host.trimmingCharacters(in: .whitespaces).isEmpty
        let userValid = kind == .mongodb || !user.trimmingCharacters(in: .whitespaces).isEmpty
        return hostValid && userValid && portValid
    }

    static func build(
        kind: DatabaseKind,
        name: String,
        host: String,
        port: String,
        user: String,
        database: String,
        filePath: String
    ) -> ConnectionProfile? {
        guard isValid(kind: kind, host: host, port: port, user: user, filePath: filePath) else { return nil }
        if kind == .sqlite {
            let path = filePath.trimmingCharacters(in: .whitespaces)
            return ConnectionProfile(
                name: name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : name,
                kind: .sqlite,
                host: "",
                port: 0,
                user: "",
                database: SQLiteDriver.mainDatabase,
                filePath: path,
                readOnly: false
            )
        }
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard let portNum = Int(port) else { return nil }
        let db = database.trimmingCharacters(in: .whitespaces)
        let defaultProfileName = db.isEmpty ? trimmedHost : db
        return ConnectionProfile(
            name: name.isEmpty ? defaultProfileName : name,
            kind: kind,
            host: trimmedHost,
            port: portNum,
            user: user,
            database: database
        )
    }

    static func defaultPort(_ kind: DatabaseKind) -> String {
        switch kind {
        case .postgres: "5432"
        case .mysql: "3306"
        case .mongodb: "27017"
        case .sqlite: ""
        }
    }

    static func defaultUser(_ kind: DatabaseKind) -> String {
        switch kind {
        case .postgres: "postgres"
        case .mysql: "root"
        case .mongodb, .sqlite: ""
        }
    }
}
