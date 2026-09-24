# 10. Current State, Performance & Technical Debt

[Previous: Testing Strategy](09-testing.md) · [Index](README.md) · [Next: Specification Parity & Extensions](11-specification-parity-and-extensions.md)

---

## 1. Working Tree Audit & Verified Foundations

The working tree of KTStack represents a stable, modular native macOS application with clear architectural boundaries:

| Subsystem | Architectural Status | Proven Implementation |
|---|---|---|
| **Build & Project Spec** | **Stable** | Generated strictly via XcodeGen (`project.yml`). Zero `.xcodeproj` manual edits. |
| **Package Layering** | **Stable** | Tiered SPM packages (`KTStackCore` → `KTPlatformContracts` → `KTPluginKit` → Feature Plugins) enforced by CI gate. |
| **Network & DNS** | **Stable** | Privileged helper manages `/etc/resolver/test` and `dnsmasq` on port 53. Root CA installed with `-p ssl -p basic`. |
| **Reverse Proxy** | **Stable** | Dual-tier Front Nginx (:80/:443) and per-site Loopback Backend Nginx (:4000-4999). |
| **Database Editor** | **Stable (Clean-Room)**| 100% MIT implementation. AppKit floating `KTCellOverlayEditor`, `KTGridKeyHandlingTableView`, PK-indexed `StagedTableEditor`. |
| **UI Design System** | **In Transition** | Standards locked to **`SwiftUI + Liquid Glass + Apple HIG`** with availability fallbacks (`#available(macOS 27, *)`). |

---

## 2. Identified Technical Debt & Open Architecture Items

### 2.1 Monolithic Remnants in `KTStackKit`
- **Current State**: While feature packages (M04–M09: Dumps, Mail, Logs, Tunnel, Doctor, Database) have been extracted into isolated SPM packages under `Packages/Features/`, certain core platform services (Site provisioning, Nginx configuration generation) still reside in `KTStackKit`.
- **Debt Impact**: `KTStackKit` acts as a large internal framework. Ongoing refactoring should split site provisioning into a distinct contract-backed service to complete full modular isolation.

### 2.2 Relocated Runtime Maintenance Surface
- **Current State**: PHP 7.4 through 8.5 are vendored as relocated Homebrew bottles where every non-system dylib is rewritten via `@loader_path/../lib`.
- **Maintenance Cost**: Each PHP point release requires re-running `scripts/build-php-from-brew.sh`, re-verifying ~35–40 dynamic libraries per version, and re-signing all binaries with the Developer ID certificate to satisfy Hardened Runtime library validation.

### 2.3 Legacy Node Process Fields
- **Current State**: Node.js sites operate on a reverse-proxy model (forwarding to `localhost:<nodePort>` managed by the user).
- **Debt Impact**: Legacy fields `nodeCommand` and `nodeEnabled` persist in `sites.json` for backward compatibility, although they are ignored by the runtime proxy engine.

---

## 3. Performance Bottlenecks & Guardrails

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      GPU & Compositor Guardrail                        │
│  Never apply .glassEffect() per-row in virtualized tables or logs!     │
├────────────────────────────────────────────────────────────────────────┤
│                      Memory & Identity Guardrail                       │
│  Index staged edits strictly by Primary Key, never visual row index!   │
├────────────────────────────────────────────────────────────────────────┤
│                      Thread & Concurrency Guardrail                    │
│  All NIO socket operations and DB drivers run on dedicated event loops!│
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Liquid Glass GPU Fill-Rate & Invalidation Storms
- **Risk**: Liquid Glass applies real-time optical blur and reflection shaders. If attached to individual cells or repeatedly invalidated by broad `@Observable` state updates, frame rates drop below 60fps on high-density displays.
- **Guardrail**: Liquid Glass must be reserved for container shells (toolbars, sidebars, modal cards, floating panels) and batched inside `GlassEffectContainer(spacing:)`. Use `swiftui-performance-audit` to inspect view invalidations.

### 3.2 Virtualized Database Table Scrolling
- **Risk**: Tables with hundreds of columns or wide text blobs can trigger memory spikes and frame drops during fast keyboard scrolling (`ArrowDown` / `PageDown`).
- **Mitigation**: `KTGridKeyHandlingTableView` leverages AppKit's native cell reuse queue and virtual row height caching. Data is paged via sliding windows from driver queries.

---

[Previous: Testing Strategy](09-testing.md) · [Index](README.md) · [Next: Specification Parity & Extensions](11-specification-parity-and-extensions.md)
