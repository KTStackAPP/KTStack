# Package dependency rules

Frozen boundary from the Plugin Architecture design (section 4). Tiers may depend
only downward. The SPM manifests are the primary fence; a forbidden dependency
fails to compile. `scripts/architecture-check.sh` is the backstop and runs first
in the local gate (`scripts/ci-local.sh`, both quick and full), so a violation
surfaces before lint instead of at merge.

## Allowed dependencies

```text
App                 → every plugin, KTStackKit, KTPluginKit, KTPlatformContracts, KTStackCore, Sparkle
Feature Plugin      → KTPluginKit, KTPlatformContracts, KTStackCore, its own SPM deps
KTStackKit          → KTPlatformContracts (implements), KTStackCore
KTPluginKit         → KTStackCore, SwiftUI
KTPlatformContracts → KTStackCore
KTStackCore         → Foundation + minimal Apple system frameworks (Security)
Helper / Resolver   → KTStackCoreStatic
```

## Forbidden

```text
Plugin        ✗→ Plugin          (they meet through a contract or the platform; App wires them)
Plugin        ✗→ KTStackKit      (a plugin never sees a platform implementation)
KTStackKit    ✗→ Plugin, KTPluginKit
Contracts     ✗→ KTStackKit, Plugin, SwiftUI, AppKit
KTStackCore   ✗→ everything else
```

Two lines carry the weight:

- **Plugin ✗→ KTStackKit** is the one that makes this modular instead of just
  foldered. If a plugin imported the platform implementation, renaming
  `SiteRegistry` → `WorkspaceRegistry` would force every plugin to change. With
  contracts in the middle, the platform refactors freely and a plugin only knows
  `SiteProviding`.
- **KTStackCore ✗→ everything else** keeps the privilege surface small: the root
  helper links Core, so Core must not pull in UI or platform code.

## What the check enforces

Manifest layer: each `Packages/<tier>/<pkg>/Package.swift` may declare local
package-path deps only from its allowed set (Contracts and Plugin → KTStackCore;
Core → none; Features → KTStackCore, KTPlatformContracts, KTPluginKit). External
SPM deps are unrestricted.

Import layer (`^import` lines in `Sources/`):

- `Packages/Core/**`: only Foundation and Security.
- `Packages/Contracts/**`: no SwiftUI, AppKit, KTStackKit, KTPluginKit.
- `Packages/Plugin/**`: no KTStackKit, KTPlatformContracts.
- `KTStackKit/Sources/**`: no KTPluginKit.
- `Packages/Features/**` (M04+): no KTStackKit, no sibling feature package.
