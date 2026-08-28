# 0003. MySQL/MariaDB editor built independently under MIT

Status: Accepted (2026-08-28)

## Context

The database editor was scoped as a port of the AGPL editor. the AGPL editor at commit
`the source commit` is AGPL-3.0. AGPL section 5(c) requires a modified work to be
licensed as a whole under AGPL when conveyed. Renaming files, moving code into
KTStack folders, dropping attribution or rewriting syntax does not strip the
source license from an adapted work. Releasing KTStack (root MIT) with adapted
the AGPL editor code is not possible without relicensing the whole app.

The [MIT license review](../../../plans/260828-1133-tablepro-mysql-db-editor-port/reports/license-review-mit.md)
sets the boundary and dependency decisions.

## Decision

Build the MySQL/MariaDB editor independently. No the AGPL editor source, tests, assets,
strings, file layout, UI composition or implementation detail is copied,
translated or adapted, from `the source commit` or any other revision. The the AGPL editor
CodeEdit forks are rejected inputs (the AGPL editor changes may be AGPL); an upstream
CodeEdit release may be used only after an exact-tag transitive license audit,
otherwise KTStack keeps its current SQL editor.

Rejected: the AGPL-port design. It cannot ship in an MIT app.

Route to MIT relicensing of the AGPL editor material stays blocked. It would need a
separate written grant from every required the AGPL editor copyright holder that
explicitly permits the exact files and modifications to be distributed under
MIT. A product purchase, repo access or attribution is not that grant. Such a
grant requires a new plan decision and a superseding ADR.

Dependencies:

- Keep MySQLNIO (MIT), already integrated.
- Do not add MariaDB Connector/C (LGPL-2.1-or-later) to the default design.
- Every new dependency and feature area is recorded in the
  [source-provenance register](../../legal/mysql-editor-source-provenance.md)
  before code lands.
- `scripts/release/license-audit.sh` fails if an app-linked SPM dependency is
  copyleft or unknown. Separately distributed executables (bundled engines) keep
  their own licenses and the written source offer.

## Consequences

- KTStack root `LICENSE` stays MIT; the macOS 13 deployment target is unchanged.
- Requirements cite KTStack product goals and MySQL/MariaDB public docs, never
  the AGPL editor paths or internal symbols. An implementer who has read the AGPL editor source
  is limited to public functional requirements and review.
- The final diff is reviewed for copied identifiers, strings, unusual control
  flow and structural similarity before release.

## Links

- Plan: [plans/260828-1133-tablepro-mysql-db-editor-port/plan.md](../../../plans/260828-1133-tablepro-mysql-db-editor-port/plan.md)
- License review: [reports/license-review-mit.md](../../../plans/260828-1133-tablepro-mysql-db-editor-port/reports/license-review-mit.md)
- Provenance register: [docs/legal/mysql-editor-source-provenance.md](../../legal/mysql-editor-source-provenance.md)
