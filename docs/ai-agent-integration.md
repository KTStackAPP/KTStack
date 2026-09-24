# AI Agent Integration with KTStack (MCP & CLI)

KTStack includes a native Model Context Protocol (MCP) server embedded inside the `kt` command-line interface (`kt mcp`). It operates over standard I/O (`stdio`), allowing AI coding assistants such as Cursor, Claude Code, and Windsurf to directly introspect, manage, and debug your local PHP/Node.js environment without leaving your editor.

---

## 1. Setup Guide

### Cursor Configuration
Add KTStack to your project or global Cursor configuration (`~/.cursor/mcp.json` or `.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "ktstack": {
      "command": "/Applications/KTStack.app/Contents/MacOS/kt",
      "args": ["mcp"]
    }
  }
}
```

### Claude Code Configuration
Run the following terminal command to register KTStack with Claude Code:

```bash
claude mcp add ktstack -- /Applications/KTStack.app/Contents/MacOS/kt mcp
```

---

## 2. Available MCP Tools

KTStack exposes 6 AI tools over the MCP stdio protocol:

| Tool | Parameters | Description |
|---|---|---|
| `ktstack_list_sites` | none | Returns all registered `.test` sites, domains, PHP versions, loopback backend ports, and disk paths. |
| `ktstack_list_services` | none | Returns each background service and whether it is running. |
| `ktstack_restart_service` | `service` (string, required) | Restarts a service (`nginx`, `phpFpm`, `mysql`, `postgres`, `redis`, …); a stopped service is started. |
| `ktstack_get_recent_logs` | `source` (string), `lines` (integer, max 2000) | Returns the last lines of a log source: `nginx-error` (default), `nginx-access`, `php-<version>`, a service such as `mysql`, `diagnostics`, or `site-<domain>-error` / `site-<domain>-access`. An unknown source returns the list of available ids. |
| `ktstack_backup_database` | `database` (string, required) | Not available yet: returns an error. Back up from KTStack › Database › Backups. |
| `ktstack_doctor` | none | Reports whether the KTStack app answers on the local IPC socket. |

Notifications (JSON-RPC messages without an `id`) are processed but never answered.

---

## 3. Architecture & Security Invariants

- **Local IPC Unix Socket**: The `kt` tool and MCP server talk directly to `KTStack.app` via `/Users/<user>/Library/Application Support/KTStack/run/ktstack.sock`.
- **Zero Network Egress**: All communication occurs exclusively over local Unix domain sockets and stdio pipes. No telemetry or query data is sent externally.
- **Strict Permission Boundaries**: Socket permissions are restricted to user `0600`, preventing non-owner local processes from sending commands to KTStack.
