import Foundation
import KTStackCore

struct SitesCommand {
    let client: KTIPCClient

    func run(arguments: [String]) throws {
        let jsonOutput = arguments.contains("--json")
        let raw = try client.call(method: "sites.list")

        if jsonOutput {
            print(raw)
            return
        }

        guard let data = raw.data(using: .utf8),
              let sites = try? JSONDecoder().decode([KTIPCSiteInfo].self, from: data) else {
            print(raw)
            return
        }

        if sites.isEmpty {
            print("No sites registered in KTStack.")
            return
        }

        print(String(format: "%-20@ %-25@ %-8@ %-6@ %-6@ %@", "NAME", "DOMAIN", "PHP", "HTTPS", "PORT", "PATH"))
        print(String(repeating: "-", count: 85))

        for site in sites {
            print(String(
                format: "%-20@ %-25@ %-8@ %-6@ %-6d %@",
                site.name,
                site.domain,
                site.phpVersion,
                site.secure ? "yes" : "no",
                site.backendPort,
                site.path
            ))
        }
    }
}
