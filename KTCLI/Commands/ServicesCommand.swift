import Foundation
import KTStackCore

struct ServicesCommand {
    let client: KTIPCClient

    func run(arguments: [String]) throws {
        if let action = arguments.first, ["start", "stop", "restart"].contains(action) {
            guard arguments.count >= 2 else {
                throw KTCLIError.serverError("Usage: kt services \(action) <service>")
            }
            let result = try client.call(method: "services.\(action)", params: ["service": arguments[1]])
            print(result)
            return
        }

        let jsonOutput = arguments.contains("--json")
        let raw = try client.call(method: "services.list")

        if jsonOutput {
            print(raw)
            return
        }

        guard let data = raw.data(using: .utf8),
              let services = try? JSONDecoder().decode([KTIPCServiceInfo].self, from: data) else {
            print(raw)
            return
        }

        print(String(format: "%-16@ %-10@ %@", "SERVICE", "STATUS", "DETAIL"))
        print(String(repeating: "-", count: 60))

        for svc in services {
            let status = svc.running ? "running" : "stopped"
            print(String(
                format: "%-16@ %-10@ %@",
                svc.name,
                status,
                svc.detail ?? ""
            ))
        }
    }
}
