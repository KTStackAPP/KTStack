import Foundation
import KTStackCore

func printUsage() {
    print("""
    KTStack Command-Line Interface (kt)

    USAGE:
      kt <command> [options]

    COMMANDS:
      sites [list] [--json]         List registered local sites
      services [list] [--json]      List service statuses
      services restart <service>    Restart a specific background service
      db backup [name]              Trigger database backup
      doctor                        Run diagnostic probes
      mcp                           Start stdio Model Context Protocol server
      version, --version, -v        Print version
      help, --help, -h              Show this help message
    """)
}

let args = Array(CommandLine.arguments.dropFirst())
let client = KTIPCClient()

guard let command = args.first else {
    printUsage()
    exit(0)
}

switch command {
case "sites":
    do {
        let cmd = SitesCommand(client: client)
        try cmd.run(arguments: Array(args.dropFirst()))
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "services":
    do {
        let cmd = ServicesCommand(client: client)
        try cmd.run(arguments: Array(args.dropFirst()))
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "doctor":
    let cmd = DoctorCommand(client: client)
    cmd.run()

case "db":
    do {
        let cmd = DatabaseCommand(client: client)
        try cmd.run(arguments: Array(args.dropFirst()))
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

case "mcp":
    Task {
        let transport = KTMCPTransport()
        await transport.run()
        exit(0)
    }
    dispatchMain()

case "version", "--version", "-v":
    print("kt version 0.3.0 (build 36)")
    exit(0)

case "help", "--help", "-h":
    printUsage()
    exit(0)

default:
    fputs("Unknown command: \(command). Run 'kt --help' for usage.\n", stderr)
    exit(1)
}
