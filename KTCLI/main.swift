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
if args.first == ProcessWatchdog.command {
    guard let parsed = ProcessWatchdog.parse(Array(args.dropFirst())) else {
        fputs("usage: kt tunnel-watchdog --parent-pid <pid> [--deadline <epoch>] -- <program> [args]\n", stderr)
        exit(64)
    }
    exit(parsed.watchdog.run(executable: parsed.executable, arguments: parsed.arguments))
}
let client = KTIPCClient()
let resolver = ShellToolResolver()
guard resolver.isToolEnabled("kt") else {
    fputs("ktstack: kt is not enabled — open KTStack > Shell Integration to enable it\n", stderr)
    exit(127)
}


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
    if args.contains("--help") || args.contains("-h") {
        print("""
        KTStack Model Context Protocol (MCP) Server

        USAGE:
          kt mcp

        DESCRIPTION:
          Runs a stdio-based MCP Server exposing KTStack capabilities to AI coding agents
          (Claude Desktop, Cursor, Claude Code, Windsurf, etc.).

        CONFIGURATION (Claude Desktop / Cursor):
          Add to claude_desktop_config.json or .cursor/mcp.json:
          {
            "mcpServers": {
              "ktstack": {
                "command": "kt",
                "args": ["mcp"]
              }
            }
          }

        AVAILABLE TOOLS:
          • ktstack_list_sites: List all local development sites and ports
          • ktstack_list_services: Inspect background service daemons
          • ktstack_create_site: Register a new local development site
          • ktstack_switch_php_version: Switch PHP version for a site
          • ktstack_get_recent_logs: Fetch trailing error logs
          • ktstack_inspect_db_schema: Inspect database schema and tables
          • ktstack_backup_db: Trigger database backup
        """)
        exit(0)
    }
    Task {
        let transport = KTMCPTransport()
        await transport.run()
        exit(0)
    }
    dispatchMain()

case "version", "--version", "-v":
    print("kt version 0.3.1 (build 37)")
    exit(0)

case "help", "--help", "-h":
    printUsage()
    exit(0)

default:
    fputs("Unknown command: \(command). Run 'kt --help' for usage.\n", stderr)
    exit(1)
}
