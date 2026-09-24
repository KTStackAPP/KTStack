# KTStack Engineering Doctrine

> Immutable architectural tenets, engineering invariants, and design doctrine governing KTStack development across all sessions and contributors.

---

## 1. Core Mission & Invariant Tenets

1. **Native macOS First**: KTStack is a 100% native macOS developer environment for PHP & Node.js. It runs as a lightweight menu-bar application without Docker or Homebrew runtime dependencies.
2. **Clean-Room & License Provenance**: All code in KTStack is strictly **MIT licensed**. Zero code from AGPL-3.0 or proprietary tools (such as TablePro or TablePlus) may be copied, ported, or adapted. All AppKit/SwiftUI patterns must be clean-room implementations.
3. **XcodeGen as Source of Truth**: The Xcode project is generated programmatically from `project.yml`. Never edit `KTStack.xcodeproj` manually. Changes to targets, dependencies, schemes, or compiler settings must be made in `project.yml` and verified via `xcodegen generate`.
4. **Real Implementation Only**: Never mock, stub, fake, or simulate logic just to pass builds or test suites. All features must be fully functional and testable on real local runtimes.
5. **Strict Comment Policy**: Code must be 100% self-documenting through precise naming, type safety, modular structures, and small focused functions. Comments (`//`, `/* */`, `MARK:`, `TODO:`, `FIXME:`, header comments) are forbidden in source code. Explanations and architectural decisions belong exclusively in `docs/`, `ADR/`, or markdown documentation.

---

## 2. UI & Design Doctrine: `SwiftUI + Liquid Glass + Apple HIG`

### 2.1 Standard Terminology & Concepts
- **Keyword Standard**: Always use **`SwiftUI + Liquid Glass + Apple HIG`** when designing or implementing next-generation macOS UI. Never refer to it simply as generic "glassmorphism" (which denotes static CSS blur filters on web).
- **Material vs. Framework**:
  - **Liquid Glass** is Apple's unified design language and dynamic optical material introduced in modern macOS/iOS (macOS 27+, iOS 27+). It features real-time backdrop blur, environmental light/color reflection, fluid boundary reactions, and state-driven morphing.
  - **SwiftUI** is the native declarative framework implementing this material in Swift.

### 2.2 Native Liquid Glass APIs
Always prefer Apple's native APIs over custom blur shaders:
- **Surfaces**: `.glassEffect(.regular.tint(...).interactive(), in: .rect(cornerRadius: ...))`
- **Containers**: Group multiple glass elements inside `GlassEffectContainer(spacing:)` to merge optical passes and enable fluid morphing.
- **Buttons**: Use native styles `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`.
- **Transitions**: Combine `glassEffectUnion(id:namespace:)` and `glassEffectID(_:in:)` with `@Namespace` and SwiftUI animation blocks.

### 2.3 Modifier Ordering Discipline
Layout, padding, and sizing modifiers MUST precede `.glassEffect(...)`:
```swift
Text(title)
    .font(.system(size: 13, weight: .medium))
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .glassEffect(.regular.interactive(), in: .capsule)
```
Applying `.glassEffect()` before padding distorts refraction bounding boxes and causes visual clipping.

### 2.4 Backward Compatibility & Availability Fallback
- **Deployment Target**: KTStack supports **macOS 13.0 (Ventura) and newer**.
- **Availability Guard**: Every use of Liquid Glass APIs (macOS 27+) must be gated with `#available(macOS 27, *)` and paired with a production-grade fallback:
```swift
if #available(macOS 27, *) {
    content
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: KTRadius.card))
} else {
    content
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: KTRadius.card))
}
```
Encapsulate repetitive availability branches within reusable `KTPluginKit` view modifiers or styling tokens.

### 2.5 Performance Guardrails for Glass Materials
- **No Per-Cell Glass in Dense Grids**: Never apply real-time `.glassEffect()` per cell or per row inside virtualized tables (`KTGridKeyHandlingTableView`), log streams, or long site lists. Doing so triggers catastrophic GPU fill-rate exhaustion and layout thrash.
- **Chrome & Cards Only**: Reserve Liquid Glass for window chrome, toolbars, sidebars, modal dialogs, inspector panels, and floating action bars.
- **Render Batching**: Adjacent glass elements must be wrapped in `GlassEffectContainer` so the compositor batches them in a single offscreen render pass.

---

## 3. Modular Architecture & Dependency Boundaries

KTStack follows a strict modular structure across local Swift packages:

```
Packages/
├── Core/
│   └── KTStackCore            # XPC contracts, DNS/TLS constants, path resolvers
├── Contracts/
│   └── KTPlatformContracts    # Service capability protocols
├── Plugin/
│   └── KTPluginKit            # Design tokens, shared KT* components, plugin contracts
└── Features/
    ├── KTDumpsPlugin          # dd() / dump() stream viewer
    ├── KTMailPlugin           # Mailpit integration
    ├── KTLogsPlugin           # Unified log viewer
    ├── KTTunnelPlugin         # Cloudflare Tunnel sharing
    ├── KTDoctorPlugin         # System & port diagnostic probes
    └── KTDatabasePlugin       # Pure-Swift drivers (MySQL, PG, SQLite, Mongo) & editor
```

### Invariants:
1. **Feature Package Isolation**: Feature packages (`KTDumpsPlugin`, `KTDatabasePlugin`, etc.) depend strictly on `KTStackCore`, `KTPlatformContracts`, and `KTPluginKit`. They must **never** import `KTStackKit`.
2. **File Size Limit**: Individual Swift source files must stay under **200 lines**. When a file exceeds 200 lines, decompose it into focused subviews, dedicated controller helpers, or domain models.
3. **Kebab-Case Naming**: File names must use descriptive kebab-case (e.g. `database-editor-table-view.swift`) to ensure instant self-documentation for search tools.

---

## 4. Subsystem Invariants

### 4.1 Database Editor Grid Architecture
- **Floating Overlay Editor (`KTCellOverlayEditor`)**: Bypasses AppKit's default `NSTextFieldDelegate` field editor to prevent focus trapping and preserve Tab/Enter/Arrow navigation.
- **Key Interception (`KTGridKeyHandlingTableView`)**: Intercepts keyboard events before standard AppKit dispatch for instant type-to-edit, draft row insertion (`⌘N`), deletion, and commit (`⌘S`).
- **PK-Indexed Staging (`StagedTableEditor`)**: Dirty cells and staged rows must be tracked strictly by **primary key (PK)**, never by volatile visual row indices, guaranteeing state integrity during virtual scrolling, sorting, and sliding pagination.
- **Transaction Parity**: Driver transactions must execute atomically (`$N` parameter binding in `PostgresDriver`, `BEGIN IMMEDIATE TRANSACTION` in `SQLiteDriver`).

### 4.2 macOS Root CA Trust & Verification
- **Privileged Installation**: Root CA installation into the System Keychain must specify `-p ssl -p basic` flags on `security add-trusted-cert`.
- **Trust Evaluation**: Never rely on CLI `security find-certificate` (which only checks keychain presence, not trust status). Trust must be evaluated via native `Security.framework` APIs (`SecTrustSettingsCopyTrustSettings`, `SecTrustEvaluateWithError`).

---

## 5. Agent Skills Doctrine

For all Swift, SwiftUI, and macOS UI tasks, agents must activate and route according to the **Core SwiftUI Triad**:

| Skill | Author / Source | Primary Responsibility |
|---|---|---|
| **`swiftui-pro`** | `twostraws` | SwiftUI best practices, modern APIs, data flow, Apple HIG, accessibility, state management. |
| **`swiftui-liquid-glass`** | `Dimillian` | Native Liquid Glass implementation, `.glassEffect()`, `GlassEffectContainer`, glass button styles, modifier order, fallbacks. |
| **`swiftui-performance-audit`** | `Dimillian` | Invalidation storms, render loops, layout thrash, memory footprint, Instruments profiling. |

Supporting specialized skills:
- **`swiftui-ui-patterns`**: Layout structures, responsive stacks/grids, custom modifiers.
- **`swiftui-view-refactor`**: View body decomposition, `@Observable` standardizations.
