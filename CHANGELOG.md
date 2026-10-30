# Changelog

## 0.3.6.3 - 2026-10-30

### Added

- Sites: import your own certificate (full chain + private key) for a site. KTStack serves it on HTTPS and never re-mints, renews or deletes it. Re-import to update it. An alias or wildcard the certificate does not cover is refused.
- Sites: a details button in the header shows the inspector, and widens a narrow window to fit it.
- Sites and Settings: a warning when the TLD is HSTS-preloaded (`.dev`, `.app` and others). Browsers force HTTPS on these TLDs, so a site with HTTPS off won't load.

### Fixed

- An open sheet such as New Site no longer disappears when you switch to another app.

## 0.3.6.2 - 2026-10-25

### Fixed

- Shell integration: turning it on now downloads WP-CLI along with Composer, so `wp` works in a new terminal for imported WordPress sites too. Settings names any tool whose download did not finish.
- Database: PostgreSQL connections default to TLS `prefer`. A TLS failure now says whether the server refused TLS or the handshake failed (for example a self-signed certificate) and which TLS setting to try.
- Database: the DDL source sheet shows the `CREATE TABLE` and `CREATE VIEW` statement for PostgreSQL and SQLite tables.

### Changed

- Database: the workspace window responds faster. Object tabs keep their pane when you switch instead of rebuilding it, the data grid stays on screen while a table loads, and the ER diagram redraws only when the diagram changes.

## 0.3.6.1 - 2026-10-09

### Fixed

- Database: PostgreSQL `timestamp`, `timestamptz`, `date`, `time`, `timetz`, `interval` and `numeric` columns show their values instead of unreadable bytes. `timestamptz` shows in UTC (`+00`), and `numeric` keeps its scale (`12.50`).
- Database: the row inspector is easier to read. Column names and types use stronger text colors, long type names stay on one line, and the inspector edge, header and field borders are darker.

## 0.3.6 - 2026-10-06

### Changed

- Sites: a fixed-width list beside a wide site detail pane. Search and kind filters share one row above both, and search also matches a PHP version ("PHP 8.4"). The detail shows Domain, Security & Sharing, Runtime and Advanced cards in two columns, with environment variables, nginx directives and workers edited in their own sheets. Site Settings moved into the detail; grid view removed. The server control sits in the header and DNS status under the list.
- Logs: newest line on top. Following keeps the view at the top as lines arrive, so opening a log no longer starts at the oldest line.
- Switching dashboard tabs is faster: the sidebar no longer re-renders twice per switch, and a tab starts its polling and log tail after it first draws.
- The Sites list scrolls without per-row work: installed editors are read once and refreshed when the app becomes active, and site frameworks publish in one update.

### Fixed

- Dark mode: Mail, Dumps, Services, Database backups, modals, form fields and segmented tabs no longer draw white panels behind white text. The sidebar uses the native sidebar material and full-contrast row labels.

## 0.3.5 — 2026-10-05

### Changed

- Release builds are now checked for a working server start before they ship: the release smoke test launches the app and fails unless nginx comes up and no binary is rejected. No app behavior changes in this version.

## 0.3.4 — 2026-10-05

### Fixed

- The server and database engines start again. 0.3.2 and 0.3.3 rejected their own signed binaries (nginx, MySQL, PostgreSQL, Redis, MongoDB, Mailpit, Memcached) with "Code signature check failed", so nothing could start.

## 0.3.3 — 2026-10-05

### Added

- **Background workers** in **Site Settings… → Workers**: run long-lived commands such as `php artisan queue:work` and `php artisan schedule:work` for a PHP site, supervised by KTStack. Laravel sites get one-click queue and scheduler presets. Workers use the site's PHP version, folder and environment variables, run while the server runs, restart with backoff when they crash (and stop retrying after repeated quick crashes), and stop with the server or when KTStack quits. Start, stop and restart each worker; the site card shows how many are running. Output goes to **Logs** as `<domain> · worker <name>`. Workers are off until you press **Start**. `kt workers` and the MCP `ktstack_list_workers`, `ktstack_start_worker` and `ktstack_stop_worker` tools list, start and stop them.
- **Wildcard subdomains** in **Site Settings…**: a site can answer on every subdomain of its domain, so `tenant.shop.test` reaches the `shop.test` site without adding each one as an alias. Useful for WordPress multisite in subdomain mode and multi-tenant apps. It is off by default. On an HTTPS site the certificate is re-issued with `*.shop.test`. A site or alias with its own domain (for example `api.shop.test`) still wins over the wildcard. `kt sites` and the MCP `ktstack_list_sites` tool show the flag.

### Changed

- The update window now shows what changed in the new version.

### Fixed

- Apache backends no longer redirect an alias domain to the site's main domain (for example when adding a trailing slash to a folder URL). Apache now keeps the host from the request and only pins the port.

## 0.3.2 — 2026-10-05

### Added

- Scheduled backups in **Settings → Scheduled Backups**. A plan backs up the databases you pick, and optionally site source code and KTStack settings, into one archive every day or every week, and keeps the last N archives. A missed time (Mac asleep or KTStack closed) runs once as soon as possible; plans can skip runs on battery power.
- Backup destinations in **Settings → Backup Destinations**: a local folder (external drive, network share, synced folder), any S3-compatible storage (Amazon S3, Cloudflare R2, Backblaze B2, MinIO, Wasabi, DigitalOcean Spaces or a custom endpoint) or a Google Drive folder. Each plan uploads to one destination and can keep a copy on this Mac. Secrets are stored in the Keychain, and **Test Connection** checks a destination before you use it.
- Google Drive sign-in uses your browser and only asks for access to files KTStack creates or that you pick. Choose a folder KTStack created, create a new one, or pick any existing folder with Google's picker.
- **Restore…** on a plan downloads an archive, verifies its checksum, adds its database dumps to **Database → Backups** and copies site folders and settings into Downloads.

### Changed

- MongoDB documents are now shown and saved as Extended JSON. Decimal128 values show their real value instead of an unreadable placeholder, and documents containing Decimal128, binary subtypes, regular expressions or JavaScript code can now be edited without losing those types. Binary data is shown in the canonical `{"$binary": {"base64", "subType"}}` form.
- New local certificate authorities are created with name constraints: they can only sign certificates for `.test`, `.home.arpa`, `.internal`, your dev TLD and loopback IPs. An existing CA can be replaced from **Settings → HTTPS Certificates → Regenerate CA**; the old CA is kept in a `retired` folder. Turn this off with **Restrict CA to dev domains**.
- Server start, stop and restart clicked while another server operation is running are now queued and run once it finishes, instead of being ignored. Turn this off in **Settings → General → Queue actions while busy**.
- Editing sites now reloads only the site backends whose configuration changed, instead of all of them.
- Launch, the HTTPS certificate settings and the PHP version list no longer block the interface while they read from disk.
- SQL syntax highlighting now re-colours only the edited line on large queries.
- External tools (`lsof`, `php-fpm -t`, `codesign`, `launchctl`) now run with timeouts, so a hung tool can no longer freeze KTStack.

### Upgrade notes

- The privileged helper is now version 0.3.1. KTStack asks you to approve the helper again after updating.
