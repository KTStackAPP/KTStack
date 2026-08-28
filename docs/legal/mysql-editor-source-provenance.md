# MySQL/MariaDB editor: source provenance register

Purpose: prove that the MySQL/MariaDB database editor is written independently
and carries no the AGPL editor-derived material. One row per dependency and one row per
feature area, each with author, source basis, license and reviewer. Update this
file in the same change that adds a dependency or starts a feature area.

Boundary: see [ADR 0003](../architecture/adr/0003-mysql-editor-mit-provenance.md)
and the [license review](../../plans/260828-1133-tablepro-mysql-db-editor-port/reports/license-review-mit.md).

## Prohibited inputs

- the AGPL editor source at commit `the source commit` or any other revision (AGPL-3.0).
- the AGPL editor CodeEdit forks (mixed provenance; the AGPL editor changes may be AGPL).
- Any the AGPL editor string, asset, icon, screenshot, fixture, schema sample, file
  layout, UI composition or measurement.
- The local `the AGPL editor/` clone must not be present in an implementation worktree
  and must not be read during implementation. Do not delete the user's clone.

## Allowed inputs

- KTStack-owned code and existing contracts (root MIT).
- MySQL and MariaDB public protocol and SQL documentation.
- Tests written for KTStack behavior.
- Dependencies below with a recorded compatible license.

## Dependencies

App-linked (SPM) dependencies must be permissive. Copyleft or unknown app-linked
code is rejected by `scripts/release/license-audit.sh`. Separately distributed
executables (bundled engines) are audited under their own licenses with the
written source offer in `NOTICES.txt`.

| Component | Author / source basis | License | Version / URL | Reviewer |
|---|---|---|---|---|
| MySQLNIO | vapor/mysql-nio, upstream | MIT | https://github.com/vapor/mysql-nio | pending |
| PostgresNIO | vapor/postgres-nio, upstream | Apache-2.0 | https://github.com/vapor/postgres-nio | pending |
| GRDB.swift | groue/GRDB.swift, upstream | MIT | https://github.com/groue/GRDB.swift | pending |
| MongoKitten / BSON | orlandos-nl, upstream | MIT | https://github.com/orlandos-nl/MongoKitten | pending |
| SwiftNIO stack (nio, nio-ssl, nio-transport-services, atomics, collections, crypto, asn1, log, metrics, numerics, system, service-lifecycle, service-context, distributed-tracing, algorithms, async-algorithms) | apple + swift-server, upstream | Apache-2.0 | https://github.com/apple | pending |
| DNSClient | orlandos-nl, upstream | MIT | https://github.com/orlandos-nl/DNSClient | pending |
| Sparkle | sparkle-project, upstream | MIT | https://github.com/sparkle-project/Sparkle | pending |

## Feature areas

One row per editor feature area. Fill in as phases 3-6 land.

| Area | Author | Source basis | License | Reviewer |
|---|---|---|---|---|
| Driver contracts (phase 2-3) | KTStack | KTStack contracts + MySQL/MariaDB public protocol docs | MIT | pending |
| Data grid and staged writes (phase 4) | KTStack | KTStack product goals + MySQL/MariaDB SQL docs | MIT | pending |
| SQL workspace and completion (phase 5) | KTStack | KTStack product goals + MySQL/MariaDB SQL docs | MIT | pending |
| Structure editor (phase 6) | KTStack | KTStack product goals + MySQL/MariaDB DDL docs | MIT | pending |

## Review checklist (per phase, before merge)

- [ ] No file reads or imports the `the AGPL editor/` clone.
- [ ] No the AGPL editor identifiers, strings or copied pseudocode in source, tests or prompts.
- [ ] Every new dependency row filled with license evidence and a reviewer.
- [ ] `scripts/release/license-audit.sh --audit-only` passes.
- [ ] Final diff reviewed for copied identifiers, strings, unusual control flow and structural similarity.
