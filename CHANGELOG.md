# Changelog

## Unreleased

### Added

- **Wildcard subdomains** in **Site Settings…**: a site can answer on every subdomain of its domain, so `tenant.shop.test` reaches the `shop.test` site without adding each one as an alias. Useful for WordPress multisite in subdomain mode and multi-tenant apps. It is off by default. On an HTTPS site the certificate is re-issued with `*.shop.test`. A site or alias with its own domain (for example `api.shop.test`) still wins over the wildcard. `kt sites` and the MCP `ktstack_list_sites` tool show the flag.

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
