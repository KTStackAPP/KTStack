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

KTStack exposes 7 AI tools over the MCP stdio protocol:

| Tool | Parameters | Description |
|---|---|---|
| `ktstack_list_sites` | none | Returns all registered `.test` sites, domains, PHP runtime pins, loopback backend ports, and disk paths. |
| `ktstack_create_site` | `path` (string, required), `php` (string) | Registers a new local project directory under KTStack with automated `.test` domain routing. |
| `ktstack_switch_php_version` | `domain` (string, required), `version` (string, required) | Dynamically changes the PHP version (e.g. 7.4 to 8.4) assigned to a site. |
| `ktstack_get_recent_logs` | `source` (string), `lines` (integer) | Fetches trailing error logs from Front Nginx, Backend Nginx, or PHP-FPM for instant debugging. |
| `ktstack_inspect_db_schema` | `database` (string, required) | Inspects tables, columns, and primary keys from local databases. |
| `ktstack_backup_db` | `database` (string, required) | Triggers an immediate clean-room database snapshot/dump. |
| `ktstack_doctor` | none | Probes local IPC socket, application support paths, and service health. |

---

## 3. Architecture & Security Invariants

- **Local IPC Unix Socket**: The `kt` tool and MCP server talk directly to `KTStack.app` via `/Users/<user>/Library/Application Support/KTStack/run/ktstack.sock`.
- **Zero Network Egress**: All communication occurs exclusively over local Unix domain sockets and stdio pipes. No telemetry or query data is sent externally.
- **Strict Permission Boundaries**: Socket permissions are restricted to user `0600`, preventing non-owner local processes from sending commands to KTStack.
