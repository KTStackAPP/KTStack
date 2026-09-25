# Changelog

## Unreleased

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
