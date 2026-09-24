# 09. Testing Strategy & Quality Assurance

[Previous: Runtime & Deployment](08-runtime-and-deployment.md) · [Index](README.md) · [Next: Current State & Technical Debt](10-current-state-and-debt.md)

---

## 1. Testing Philosophy & Test Pyramid

KTStack adheres to an evidence-grounded testing philosophy:
- **No Weightless Tests**: Tests must defend observable contracts and boundary invariants. Tautological assertions, trivial getter tests, and mock echoes are prohibited.
- **Strict Clean-Room Validation**: Validates that all database editor components and custom drivers operate cleanly without external dependencies.
- **Fail-Closed Gateways**: Architecture violations, lint regressions, and test failures block local commits and release builds.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Live Integration Gate                           │
│  scripts/integration-test.sh (Real Nginx, PHP-FPM, HTTP/TLS assertion) │
├────────────────────────────────────────────────────────────────────────┤
│                       Logic & Unit Test Suite                          │
│  xcodebuild test -scheme KTStackKit-Tests (State, Registry, Drivers)   │
├────────────────────────────────────────────────────────────────────────┤
│                      Architecture Boundary Gate                        │
│  scripts/architecture-check.sh (SPM import enforcement, layer fences)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Test Execution & Suites

### 2.1 Logic & Unit Tests (`KTStackKit-Tests`)
Covers the platform logic, registry synchronization, path calculations, and database staging mechanics:
```bash
xcodebuild -project KTStack.xcodeproj -scheme KTStackKit-Tests -destination 'platform=macOS' test
```

Key test coverage areas:
- `SiteRegistryTests`: Verifies atomic JSON reading, writing, and domain duplicate rejection.
- `KTGridStagingStateTests`: Asserts PK-indexed cell mutation, draft row insertion, and rollback tracking across virtual sorting.
- `DatabaseDriverTransactionTests`: Verifies transactional atomicity (`$N` parameter mapping in Postgres, `BEGIN IMMEDIATE` in SQLite).
- `NginxConfigGeneratorTests`: Verifies correct directives, proxy headers, and port allocation in candidate `.conf` strings.

The same scheme also runs `KTCLITests`, which compiles `KTCLI/MCP` and `KTCLI/Commands` (not `main.swift`) against `KTStackCoreStatic` so the `kt` CLI and the stdio MCP server are covered without a running app.

### 2.2 Package Tests
Every local package with a `Tests/` directory (`Packages/Core`, `Contracts`, `Plugin`, `Features`) runs with `swift test --package-path <pkg>`, both in `.github/workflows/tests.yml` and in `scripts/ci-local.sh`.

### 2.3 Test Support Utilities (`KTStackKitTests/Support`)
- `FileDescriptorCounter`: counts this process's open descriptors (`proc_pidinfo` + `PROC_PIDLISTFDS`) and reports the delta around a block, for leak regression tests.
- `FakeLaunchAgentManager`: an in-memory `LaunchAgentManaging` that records bootstrap/kickstart/bootout calls and can inject failures, so `LaunchdServiceRunner` logic runs without `launchctl`.
- `FakeExecutable`: writes a throwaway `/bin/sh` script (fixed exit code, N bytes of stderr, a TERM-ignoring sleeper) to drive process-runner tests.
- `LoopbackListener`: a bound 127.0.0.1 listener on an ephemeral port for health and port-probe tests.

---

## 3. Architecture Boundary Verification (`scripts/architecture-check.sh`)

To prevent dependency creep across local SPM packages, `scripts/architecture-check.sh` parses `Package.swift` declarations and all Swift `import` statements across `Packages/`:

```bash
scripts/architecture-check.sh
```

### Invariants Enforced:
1. **No Plugin Implementation Leaks**: Feature packages (`Packages/Features/**`) must never import `KTStackKit`.
2. **No Cross-Plugin Entanglement**: Sibling feature packages cannot import each other.
3. **Core Layer Hygiene**: `Packages/Core/**` files can import only `Foundation` and `Security` (strictly zero AppKit, zero SwiftUI).

---

## 4. Local CI Gate (`scripts/ci-local.sh`)

Developer workflows are validated using `scripts/ci-local.sh`:
- `--quick`: Runs `architecture-check.sh`, SwiftLint, and `KTStackKit-Tests`. Designed for pre-commit / pre-push git hooks.
- **Full**: Runs `--quick` plus a full Release build compilation.

```bash
# Quick local gate
scripts/ci-local.sh --quick

# Install into local git repository hooks
scripts/install-git-hooks.sh
```

---

## 5. Live End-to-End Integration Testing (`scripts/integration-test.sh`)

While unit tests exercise pure logic, `scripts/integration-test.sh` proves end-to-end operational viability against real binaries:
1. Boots real Front Nginx and Backend Nginx instances using generated configuration files.
2. Spawns an isolated PHP-FPM pool.
3. Sends live HTTP and HTTPS requests over `127.0.0.1` using `curl`.
4. Asserts expected HTTP status codes (`200 OK`), headers (`X-Forwarded-Proto: https`), and PHP runtime execution output.
5. Performs complete, clean daemon teardown upon test completion.

---

[Previous: Runtime & Deployment](08-runtime-and-deployment.md) · [Index](README.md) · [Next: Current State & Technical Debt](10-current-state-and-debt.md)
