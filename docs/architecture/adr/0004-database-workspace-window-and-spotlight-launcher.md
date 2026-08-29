# 0004. Database workspace window opened from Spotlight via a launcher stub

Status: Accepted (2026-08-29)

## Context

The database editor opened only from the Dashboard. Users asked to reach it
straight from Spotlight, the way a standalone app opens: ⌘Space, type
"Database", Enter. KTStack is a menu-bar accessory (`LSUIElement`), so it has no
Dock presence and no app name Spotlight can surface for a subview. A deep link
was also wanted so the window can be opened by URL and, later, target a specific
connection.

## Decision

Ship a tiny launcher stub app, `KTStackDatabaseLauncher`
(`com.ktstack.database-launcher`, display name "KTStack Database",
`LSUIElement`), copied into `KTStack.app/Contents/Applications`. It opens
`ktstack://database` and exits. A spike confirmed Spotlight indexes the nested
`Contents/Applications/*.app` as an Application (`kMDItemKind = "Application"`,
`kMDItemDisplayName = "KTStack Database"`), so ⌘Space finds it. CoreSpotlight
(`indexDatabaseSpotlightItem`) plus an `NSUserActivity`
(`com.ktstack.open-database`) stay as a fallback.

The URL scheme `ktstack` is claimed in the app's `Info.plist`
(`CFBundleURLTypes`). Every deep link parses through `AppURLRoute`, which lives
in `KTStackCore` so `KTStackKitTests` covers it (the App target has no test
host). `AppDelegate+DeepLink` dispatches the parsed route to
`AppDelegate+Routing`. A URL arriving before plugins finish starting is held in
`pendingURLs` and drained at the end of `applicationDidFinishLaunching`. The
menu bar gains "Open Database… ⌘⇧D".

The stub links no `KTStackKit`/`KTStackCore`/`KTPluginKit`
(`scripts/architecture-check.sh` enforces this). `sign-all-binaries.sh` signs
the nested launcher app inside-out before the outer app so hardened runtime and
the secure timestamp are in place for notarization; `smoke-test-dmg.sh` asserts
the stub is present with the right `CFBundleName`/id.

One connection per workspace tab and the Dashboard tab collapsing to an "Open
Database Panel" button are separate decisions carried by the plan and phase 6.

## Consequences

- Spotlight surfaces "KTStack Database" without giving the whole app a Dock
  icon. If a future macOS stops indexing nested `Contents/Applications` apps,
  the CoreSpotlight fallback still lists the item.
- `ktstack://` is a single, testable entry point. New routes are new
  `AppURLRoute` cases, not new ad-hoc parsing.
- The bundle nests a second signed app. Notarization needs the inside-out
  signing order; the smoke test guards the artifact users download.
- The stub carries an icon catalog, so it is ~1.7 MB (mostly `Assets.car`),
  above the "<1 MB" guideline. Acceptable; shrink the 1024 icon later if needed.

## Alternatives rejected

- CoreSpotlight only (no launcher app): the item shows as a document-like
  result, not an Application, and the spike showed the launcher approach works.
- Registering the whole app as a regular (Dock) app: breaks the menu-bar
  accessory model.
