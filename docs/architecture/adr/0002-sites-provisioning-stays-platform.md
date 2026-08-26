# 0002. Sites install/import/restore orchestration stays on the platform

Status: Accepted (2026-08-26)

## Context

M12 moved the Sites feature into `KTSitesPlugin`. The design ownership manifest
(section 5) listed the whole Sites subsystem as plugin-owned. In practice the
install, import, and restore orchestration cannot cross the plugin boundary: it
needs types a plugin must never see.

## Decision

`Install`, `Import`, `Restore`, `SiteInspector`, and `SiteScanner` stay in
`KTStackKit/Sources/Sites`, behind the `SiteProvisioning`, `WordPressRestoring`,
and `SiteIDEConfiguring` contracts.
`SiteProvisioningService` builds `MySQLController`, `SiteHTTPSProvisioner`, and the
installers itself, so `KTSitesPlugin` never constructs a platform provisioning
type or touches `AppSupportPaths`.

Reasons:

- The orchestration is fail-closed with rollback. Install seeds the ini, creates
  the DB, scaffolds, registers, then enables HTTPS, and rolls back the DB and
  folder on any failure. That order and its rollback are a platform invariant, not
  UI state.
- It needs `MySQLAdminClient` (a `mysql`/`mysqldump` CLI wrapper) and the managed
  engine's PHP binary, which a plugin is not allowed to reach (see ADR 0001 and
  the driver-free rule in dependency-rules).

The plugin drives UI state only and shows the outcome.

## Consequences

- This is a deliberate divergence from the M12 manifest, recorded here so a future
  reader does not "fix" it by moving the files into the package.
- If a later refactor exposes a provisioning contract rich enough that the plugin
  needs no platform type, revisit with a superseding ADR.

## Links

- M12 plan: [plans/260826-1156-m12-ktsites-plugin/plan.md](../../../plans/260826-1156-m12-ktsites-plugin/plan.md)
- Design report: [plugin-architecture-design-260817-2129-ktstack-feature-plugins.md](../../../plans/reports/plugin-architecture-design-260817-2129-ktstack-feature-plugins.md)
