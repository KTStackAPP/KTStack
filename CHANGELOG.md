# Changelog

## Unreleased

### Changed

- Server start, stop and restart clicked while another server operation is running are now queued and run once it finishes, instead of being ignored. Turn this off in **Settings → General → Queue actions while busy**.
- Editing sites now reloads only the site backends whose configuration changed, instead of all of them.
- Launch, the HTTPS certificate settings and the PHP version list no longer block the interface while they read from disk.
- SQL syntax highlighting now re-colours only the edited line on large queries.
- External tools (`lsof`, `php-fpm -t`, `codesign`, `launchctl`) now run with timeouts, so a hung tool can no longer freeze KTStack.

### Upgrade notes

- The privileged helper is now version 0.3.1. KTStack asks you to approve the helper again after updating.
