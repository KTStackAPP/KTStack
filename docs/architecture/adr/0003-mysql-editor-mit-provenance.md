# 0003. MySQL/MariaDB editor built independently under MIT

Status: Accepted (2026-08-28)

## Context

The database editor was scoped to match a third-party database editor that is
licensed AGPL-3.0. AGPL section 5(c) requires a modified work to be licensed as a
whole under AGPL when conveyed. Renaming files, moving code into KTStack folders,
dropping attribution or rewriting syntax does not strip the source license from
an adapted work. Releasing KTStack (root MIT) with adapted AGPL code is not
possible without relicensing the whole app.

## Decision

Build the MySQL/MariaDB editor independently. No source, tests, assets, strings,
file layout, UI composition or implementation detail is copied, translated or
adapted from any AGPL database editor. Any third-party code editor component is a
rejected input unless an upstream release passes an exact-tag transitive license
audit; otherwise KTStack keeps its current SQL editor.

Rejected: the AGPL-port design. It cannot ship in an MIT app.

Relicensing AGPL material to MIT stays blocked. It would need a separate written
grant from every required copyright holder that explicitly permits the exact
files and modifications to be distributed under MIT. A product purchase, repo
access or attribution is not that grant. Such a grant requires a new plan
decision and a superseding ADR.

Dependencies:

- Keep MySQLNIO (MIT), already integrated.
- Do not add MariaDB Connector/C (LGPL-2.1-or-later) to the default design.
- Every new dependency and feature area is recorded in an internal
  source-provenance register (kept with the plan, not published) before code
  lands.
- `scripts/release/license-audit.sh` fails if an app-linked SPM dependency is
  copyleft or unknown, and its provenance scan rejects AGPL markers and stray
  license files in KTStack-owned source. Separately distributed executables
  (bundled engines) keep their own licenses and the written source offer.

## Consequences

- KTStack root `LICENSE` stays MIT; the macOS 13 deployment target is unchanged.
- Requirements cite KTStack product goals and MySQL/MariaDB public docs, never
  another product's paths or internal symbols. An implementer who has read AGPL
  source is limited to public functional requirements and review.
- The final diff is reviewed for copied identifiers, strings, unusual control
  flow and structural similarity before release.

## Links

- Boundary detail: [dependency-rules.md](../dependency-rules.md)
- License gate: `scripts/release/license-audit.sh`
