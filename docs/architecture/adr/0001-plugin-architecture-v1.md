# 0001. Plugin architecture v1

Status: Accepted (2026-08-17)

## Context

Logic sat in one framework, `KTStackKit`. Every feature (Sites, Services,
Database, Logs, Mail, Dumps, Doctor, Tunnel, Runtimes) shared the same module, so
a feature UI could reach any platform type directly. Renaming a platform type
forced edits across unrelated features, and the framework pulled in database
drivers and SwiftUI it did not need. The M01 assessment measured the coupling and
concluded the boundary had to be a compile-time fence, not a convention.

## Decision

Five tiers, dependencies only downward:

```
App → every plugin, KTStackKit, KTPluginKit, KTPlatformContracts, KTStackCore
Feature Plugin → KTPluginKit, KTPlatformContracts, KTStackCore
KTStackKit → KTPlatformContracts, KTStackCore
KTPluginKit → KTStackCore, SwiftUI
KTPlatformContracts → KTStackCore
KTStackCore → Foundation, Security
```

- A plugin never imports `KTStackKit`. It sees the platform only through contracts
  in `KTPlatformContracts`, so the platform refactors freely behind them.
- Plugins register in a compile-time array in the App composition root, not a
  runtime discovery mechanism.
- A contract is a command set (`func`) plus a snapshot stream (`AsyncStream` of an
  `Equatable` value); the plugin wraps the stream into its own `ObservableObject`
  and never holds a concrete manager (M10+).
- Navigation between features is a plugin-owned route enum plus a closure the App
  maps to a sidebar selection id or window.
- Plugin teardown is order-independent through `PluginLifecycleCoordinator`;
  system teardown runs after, in `PlatformLifecycle`, owned by the App.

The SPM manifests are the primary fence; `scripts/architecture-check.sh` is the
backstop and runs first in the local gate.

## Consequences

- The platform framework is driver-free and SwiftUI-free; design tokens and `KT*`
  components live in `KTPluginKit`.
- Adding a feature is a new package under `Packages/Features/*`, wired once in the
  App. It cannot reach a sibling feature or a platform implementation.
- A capability a plugin needs from the platform must first become a contract; you
  cannot hand a plugin a concrete manager to shortcut a missing snapshot field.

## Links

- Design report: [plugin-architecture-design-260817-2129-ktstack-feature-plugins.md](../../../plans/reports/plugin-architecture-design-260817-2129-ktstack-feature-plugins.md)
- Boundary detail: [dependency-rules.md](../dependency-rules.md)
