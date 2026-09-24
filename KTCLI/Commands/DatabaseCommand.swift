import Foundation
import KTStackCore

struct DatabaseCommand {
    let client: KTIPCClient

    func run(arguments: [String]) throws {
        guard let action = arguments.first else {
            print("Usage: kt db backup <database-name> [mysql|postgres|mongodb]")
            return
        }

        switch action {
        case "backup":
            guard arguments.count >= 2 else {
                print("Usage: kt db backup <database-name> [mysql|postgres|mongodb]")
                return
            }
            var params = ["database": arguments[1]]
            if arguments.count >= 3 { params["engine"] = arguments[2] }
            print(try client.call(method: "db.backup", params: params))
        default:
            print("Unknown db action: \(action). Available: backup")
        }
    }
}
