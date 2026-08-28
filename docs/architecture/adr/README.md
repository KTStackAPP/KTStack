# Architecture Decision Records

Durable architecture decisions for KTStack. One file per decision, numbered
`NNNN-slug.md`, never renumbered or deleted; a reversed decision gets a new ADR
that supersedes the old one and links back.

Each ADR carries: Status (Proposed / Accepted / Superseded), Context, Decision,
Consequences. Keep it short and link to the source report or plan instead of
copying it.

- [0001](0001-plugin-architecture-v1.md): Plugin architecture v1 (5 tier, contracts, compile-time registry).
- [0002](0002-sites-provisioning-stays-platform.md): Sites install/import/restore orchestration stays on the platform.
- [0003](0003-mysql-editor-mit-provenance.md): MySQL/MariaDB editor built independently under MIT (no the AGPL editor AGPL material).

Boundary detail lives in [dependency-rules.md](../dependency-rules.md).
