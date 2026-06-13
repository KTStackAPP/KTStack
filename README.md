# KTStack

A native macOS menu-bar app that serves local sites at `https://<name>.test` with trusted TLS,
multiple language runtimes, and one-click service management — **no Docker**. A Herd/Laragon-class
local dev host for macOS 13+, built in Swift/SwiftUI.

> Free / open-source. Distributed as a Developer-ID-signed, notarized DMG with Sparkle updates.
> Author: **Nguyên Khôi** · [nguyenkhoi.dev](https://nguyenkhoi.dev)

## Features

- **Manual site registration** (Valet-`link` style) under `~/Sites/WWW/`; each site gets an editable
  `<name>.test` domain, auto-detected type (PHP / static / Node).
- **Trusted local TLS** — vendored **mkcert** mints a local CA + per-site `*.test` leaf certs, trusted
  in the System Keychain (and Firefox/NSS). One-click secure toggle per site.
- **Automatic `.test` DNS** via vendored **dnsmasq** + `/etc/resolver/test`, driven by a privileged
  helper (`SMAppService`, DNS/CA-only trust boundary) with a one-time `sudo` fallback.
- **Service manager** — nginx, PHP-FPM pools, dnsmasq, MySQL, PostgreSQL, Redis, Mailpit unified
  behind one controller. **Quitting the app stops every service** (clean shutdown); live status pills
  + start/stop/restart with immediate feedback.
- **Runtime manager** — PHP 8.4 / 8.3 / 8.1 + Node, Python, Go all install **on-demand**
  (checksum-verified, Developer-ID signed + notarized). Per-project version switching via `.kdwarmrc`
  / `.nvmrc` / `.php-version`.
- **Per-version `php.ini` editor** with a generous compiled-in **extension set** (redis, gd, intl,
  zip, soap, gmp, mysqli, pdo_*(mysql/pgsql/sqlite), pgsql, memcached, igbinary, ssh2, snmp, ldap,
  event, zstd, xsl, protobuf, xhprof, xlswriter, exif, bcmath, mbstring, opcache, …) shown read-only
  in the Runtimes card. (Static PHP → no runtime `.so` loading; the set is baked at build time.)
- **On-demand database engines** — MySQL 9.6 / PostgreSQL / Redis install through the UI (not bundled),
  so the app ships lean. `localhost` DB connections route to the bundled MySQL socket automatically.
- **Logs viewer** — live, virtualized per-service / per-site log tail with severity gutter + filter;
  the trash action clears both the view and the on-disk log file.
- **Mail catcher** — Mailpit with an embedded message viewer (sandboxed WKWebView); PHP `mail()`
  routes straight into it.
- **Auto-update** via Sparkle (EdDSA-signed appcast) and a full **Uninstall / Reset** flow.

## Architecture

Three Xcode targets, generated with **XcodeGen** (`project.yml`). The app product ships as
**`KTStack.app`** (`PRODUCT_NAME`); the build targets keep their original internal names + bundle ids
(`com.kdwarm.*`) so existing installs, the `~/Library/Application Support/KDWarm/` data dir, and
`com.kdwarm.*` launchd jobs stay compatible:

- **`KDWarm`** target → `KTStack.app`, the SwiftUI menu-bar app (`MenuBarExtra` + a
  `NavigationSplitView` dashboard).
- **`KDWarmKit`** — framework with all logic: services, runtimes, sites, TLS, DNS, logs, mail, the XPC
  contract, design tokens. (`KDWarmKitTests` covers it — 110+ unit tests.)
- **`KDWarmHelper`** — the privileged helper (root daemon); XPC surface limited to DNS + Keychain-CA.

Runtime data lives under `~/Library/Application Support/KDWarm/` (service binaries staged out of the
immutable bundle into `bin/`, language runtimes + DB engines downloaded under
`runtimes/<lang>/<version>/`, per-engine data under `data/`, configs/certs/logs alongside).

Authoritative design + decisions: `docs/tech-stack-and-architecture.md`, `docs/design-guidelines.md`.
Signing/notarization playbook: `docs/signing-and-notarization-guide.md`.

## Build from source

Requires Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
# 1. Generate the Xcode project (the .xcodeproj is gitignored)
xcodegen generate

# 2. Build the bundled service binaries (relocatable, vendored into KDWarm/Resources/bin — gitignored)
scripts/build-nginx-relocatable.sh
scripts/build-dnsmasq-relocatable.sh
# mkcert + mailpit: drop the official arm64 binaries into KDWarm/Resources/bin/ (ad-hoc signed)
# PHP/MySQL/Postgres/Redis are NOT bundled — they install on-demand (see below).

# 3. Build + test
xcodebuild -project KDWarm.xcodeproj -scheme KDWarm -destination 'platform=macOS' build
xcodebuild test -project KDWarm.xcodeproj -scheme KDWarmKit-Tests -destination 'platform=macOS'
```

On-demand engines/runtimes (PHP, Node/Python/Go, MySQL/PostgreSQL/Redis) are downloaded by the app at
runtime; their relocatable build scripts live in `scripts/build-*-relocatable.sh`,
`scripts/build-php-static.sh` + `scripts/build-php-versions.sh`, and emit hosted `tar.gz` artifacts +
checksums (published to the project's GitHub Release; manifests in
`KDWarmKit/Sources/Runtimes/RuntimeCatalog.swift` + `Services/ServiceBinaryCatalog.swift`).

## Release

Requires an Apple **Developer ID Application** identity + notarytool credentials. See
`docs/signing-and-notarization-guide.md` for the full playbook (incl. signing the on-demand artifacts).

```bash
APP=path/to/KTStack.app
DEV_ID="Developer ID Application: NAME (TEAMID)" scripts/release/sign-all-binaries.sh "$APP"
scripts/release/notarize.sh "$APP"          # notarytool submit/wait + staple
scripts/release/build-dmg.sh  "$APP"        # compressed DMG
scripts/release/license-audit.sh            # NOTICES.txt (+ GPL/SSPL source offer)
scripts/release/update-appcast.sh <dir>     # Sparkle EdDSA-signed appcast
```

## License

Free / open-source. Redistributed components (nginx, PHP, dnsmasq, mkcert, Mailpit, MySQL (GPLv2),
PostgreSQL, Redis (SSPL), Node, Sparkle) keep their own licenses — see the generated `NOTICES.txt`
(`scripts/release/license-audit.sh`), which includes a written offer of source for the GPL/SSPL
components.
