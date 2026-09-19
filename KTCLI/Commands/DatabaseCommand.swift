import Foundation
import KTStackCore

struct DatabaseCommand {
    let client: KTIPCClient

    func run(arguments: [String]) throws {
        guard let action = arguments.first else {
            print("Usage: kt db <backup> [database-name]")
            return
        }

        switch action {
        case "backup":
            let dbName = arguments.count >= 2 ? arguments[1] : "default"
            let result = try client.call(method: "db.backup", params: ["database": dbName])
            print(result)
        default:
            print("Unknown db action: \(action). Available: backup")
        }
    }
}
