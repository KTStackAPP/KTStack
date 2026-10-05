import Foundation
import KTStackCore

struct WorkersCommand {
    let client: KTIPCClient

    func run(arguments: [String]) throws {
        if let action = arguments.first, ["start", "stop", "restart"].contains(action) {
            guard arguments.count >= 3 else {
                throw KTCLIError.serverError("Usage: kt workers \(action) <site> <worker>")
            }
            let result = try client.call(
                method: "workers.\(action)",
                params: ["site": arguments[1], "worker": arguments[2]]
            )
            print(result)
            return
        }

        var listArguments = arguments
        if listArguments.first == "list" { listArguments.removeFirst() }
        let jsonOutput = listArguments.contains("--json")
        let site = listArguments.first { !$0.hasPrefix("--") }
        let raw = try client.call(method: "workers.list", params: site.map { ["site": $0] })

        if jsonOutput {
            print(raw)
            return
        }
        guard let data = raw.data(using: .utf8),
              let workers = try? JSONDecoder().decode([KTIPCWorkerInfo].self, from: data) else {
            print(raw)
            return
        }
        guard !workers.isEmpty else {
            print("No workers. Add them in KTStack › Sites › Site Settings › Workers.")
            return
        }
        print(String(format: "%-24@ %-14@ %-18@ %@", "SITE", "WORKER", "STATE", "COMMAND"))
        print(String(repeating: "-", count: 90))
        for worker in workers {
            print(String(format: "%-24@ %-14@ %-18@ %@", worker.site, worker.name, worker.state, worker.command))
        }
    }
}
