# KTStack Technical Architecture Documentation

This specification documentation suite describes the **demonstrable, working-tree reality** of the KTStack system. It reflects the live codebase, architectural invariants, tiered Swift Package Manager modularity, dual-tier Nginx reverse proxy topology, clean-room MIT AppKit database editor, and the native **`SwiftUI + Liquid Glass + Apple HIG`** UI standards.

When documentation conflicts with code, the following precedence applies:
`Live Swift source code` → `project.yml & Package.swift` → `DOCTRINE.md & CONTINUITY.md` → `Automated Test Suites` → `Other documentation`.

---

## Role-Based Reading Guide

- **Senior macOS / Swift Engineers**: Start with [01. System Overview](01-system-overview.md), [02. Source Code Architecture](02-source-code-architecture.md), [03. Data Models](03-data-models.md), then inspect target feature packages.
- **Frontend / SwiftUI & AppKit Developers**: Read [02. Source Code Architecture](02-source-code-architecture.md) (Section on `SwiftUI + Liquid Glass + Apple HIG`), [05. Business Domains](05-business-domains.md) (Database Editor Grid `KTCellOverlayEditor`), and [10. Current State & Technical Debt](10-current-state-and-debt.md).
- **Systems / DevOps / Security Engineers**: Read [04. Authentication, Authorization & Security](04-auth-and-security.md) (`SMAppService` privilege separation, XPC protocols, Root CA trust), [06. Integration & Background Processing](06-integration-and-background.md), and [08. Runtime, Configuration & Deployment](08-runtime-and-deployment.md).
- **QA & Test Automation Engineers**: Read [09. Testing Strategy](09-testing.md) and [07. API & Data Flow](07-api-and-data-flow.md).
- **Solution Architects & Technical Leads**: Read all documents, paying particular attention to [01. System Overview](01-system-overview.md), [02. Source Code Architecture](02-source-code-architecture.md), [10. Current State & Technical Debt](10-current-state-and-debt.md), and [11. Specification Parity & Extension Points](11-specification-parity-and-extensions.md).

---

## Document Index

1. [01. System Overview](01-system-overview.md) — Purpose, Proven Actors, System Boundary, Functional Domain Map, Subsystem Interaction Matrix.
2. [02. Source Code Architecture](02-source-code-architecture.md) — Tiered SPM Packages, Dependency Rules, Lifecycle, Design Patterns, Liquid Glass UI Standards.
3. [03. Data Models](03-data-models.md) — Configuration File Schemas (`sites.json`), Table Staging State, PK-Indexed Caching, Persistence.
4. [04. Authentication, Authorization & Security](04-auth-and-security.md) — Privilege Model (`SMAppService`), Helper XPC IPC, Root CA & System Keychain Trust, Entitlements.
5. [05. Business Domains](05-business-domains.md) — Sites Management, Services Supervision, Database Editor & Drivers, Dumps, Mailpit, Logs, Doctor, Tunnel.
6. [06. Integration & Background Processing](06-integration-and-background.md) — Nginx Dual-Tier Reverse Proxy, dnsmasq, mkcert TLS, PHP-FPM Pools, Launchd Agents, Sparkle Updater.
7. [07. API & Data Flow](07-api-and-data-flow.md) — XPC Contracts, Platform Capability Protocols, HTTP Request Lifecycle, Inter-Plugin Coordination.
8. [08. Runtime, Configuration & Deployment](08-runtime-and-deployment.md) — Relocated PHP Bottles (7.4–8.5), Node.js, AppSupport Layout, XcodeGen, Code Signing & Notarization.
9. [09. Testing Strategy](09-testing.md) — `KTStackKit-Tests`, Architecture Boundary Checks, Live Integration Tests with Real Daemons, Local CI Gate.
10. [10. Current State & Technical Debt](10-current-state-and-debt.md) — Working Tree Audit, GPU/CPU Performance Profiles, Virtual Scrolling, Liquid Glass Adoption.
11. [11. Specification Parity & Extension Points](11-specification-parity-and-extensions.md) — Feature Parity vs Alternatives (Herd/Valet/Laragon), Plugin SDK Extension Points.
12. [System Architecture Presentation](System_Architecture_Presentation.md) — Visual High-Level Executive Presentation Deck.

---

## Scope and Boundaries

- **Analyzed Source Scope**:
  - `KTStack/`: Main menu-bar app, windowing, App Delegate, composition root.
  - `KTStackKit/`: Platform services, site registry, runtime manager, launchd supervisor.
  - `KTStackHelper/`: Privileged root helper daemon for port 53 DNS and Root CA installation.
  - `Packages/Core/KTStackCore/`: Shared XPC contracts, AppSupport path resolvers, DNS/TLS constants. No UI.
  - `Packages/Contracts/KTPlatformContracts/`: Capability protocols isolating plugins from platform implementation.
  - `Packages/Plugin/KTPluginKit/`: Design tokens, shared UI components (`KTButton`, `KTModalCard`), plugin lifecycle protocols.
  - `Packages/Features/`: 6 independent feature packages (`KTDumpsPlugin`, `KTMailPlugin`, `KTLogsPlugin`, `KTTunnelPlugin`, `KTDoctorPlugin`, `KTDatabasePlugin`).
  - `scripts/`: Tooling pipelines for relocated binaries, signing, notarization, and architecture verification.
- **Architectural Constraints**:
  - Zero Docker dependency: All daemons and runtimes execute natively on macOS Apple Silicon.
  - Zero Homebrew dependency for end-users: Dynamic libraries are vendored and relocated with `@loader_path/../lib`.
  - 100% Clean-Room MIT: No code copied from AGPL-3.0 TablePro or proprietary tools.
  - Zero Comments Policy in Swift code: Source code is strictly self-documenting; architectural rationale resides in markdown specifications.
