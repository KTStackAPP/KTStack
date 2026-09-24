# KTStack Session Continuity Ledger

> Operational continuity state, active capabilities, recent architectural milestones, and immediate resumption protocols for AI coding agents and engineering sessions.

---

## 1. Project Context & Environment Snapshot

- **Project**: KTStack
- **Description**: Native macOS menu-bar local development environment for PHP & Node.js (trusted HTTPS, automatic `.test` domains, multiple PHP/Node runtimes, database editor, Mailpit, log stream, Cloudflare Tunnel).
- **Primary Tech Stack**: Swift 6+, SwiftUI, AppKit (high-performance virtualized grid), XcodeGen.
- **Platform Targets**:
  - Minimum Deployment Target: **macOS 13.0 (Ventura)**
  - Architecture: **Apple Silicon (arm64)**
  - Modern Visual Target: **macOS 27+ Liquid Glass (with macOS 13+ fallback)**
- **Build System**: XcodeGen via `project.yml`. Never edit `KTStack.xcodeproj` directly.

---

## 2. Active Agent Skills Catalog

The following specialized SwiftUI and system skills are installed and verified in `.agents/skills/` (symlinked into `.claude/skills/`):

| Skill Name | Upstream Source | Primary Capability |
|---|---|---|
| **`swiftui-pro`** | `twostraws/swiftui-agent-skill` | Comprehensive SwiftUI review, modern APIs, data flow, Apple HIG, accessibility, hygiene. |
| **`swiftui-liquid-glass`** | `Dimillian/Skills` | Liquid Glass design language, `.glassEffect()`, `GlassEffectContainer`, glass buttons, modifier order, fallback. |
| **`swiftui-performance-audit`** | `Dimillian/Skills` | Invalidation storms, render loops, identity thrash, memory footprint, Instruments profiling guide. |
| **`swiftui-ui-patterns`** | `Dimillian/Skills` | Layout composition, stacks, grids, responsive layouts, custom view modifiers. |
| **`swiftui-view-refactor`** | `Dimillian/Skills` | Decomposing view bodies, subview extraction, `@Observable` state hygiene. |

---

## 3. Grounded Architectural Context & Established Patterns

### 3.1 UI & Liquid Glass Standards (`DOCTRINE.md`, `docs/design-guidelines.md`)
- **Terminology**: Use **`SwiftUI + Liquid Glass + Apple HIG`** (not generic "glassmorphism").
- **APIs**: `.glassEffect()`, `GlassEffectContainer(spacing:)`, `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`.
- **Modifier Ordering**: Layout and padding modifiers must precede `.glassEffect()`.
- **Backward Compatibility**: Guard with `#available(macOS 27, *)` and fallback to `.ultraThinMaterial` or `KTPluginKit` design tokens.
- **Performance Guardrails**: Never apply `.glassEffect()` per cell/row in dense virtualized tables (`KTGridKeyHandlingTableView`) or log viewers. Reserve for outer chrome, sidebars, cards, and floating panels.

### 3.2 Database Editor Grid Architecture (`KTDatabasePlugin`)
- **Clean-Room Implementation**: MIT-licensed original code (zero AGPL TablePro code).
- **`KTCellOverlayEditor`**: Floating `NSTextView` overlay bypassing standard `NSTextFieldDelegate` focus trapping.
- **`KTGridKeyHandlingTableView`**: Intercepts key events before dispatch for keyboard navigation and shortcuts (`⌘N`, `⌘S`, `⌘Z`, `Delete`).
- **`KTGridStagingState`**: PK-indexed dirty/staged cell management to maintain integrity across virtual scrolling.
- **Atomic Parity**: Postgres uses `$1, $2` positional parameters; SQLite uses `BEGIN IMMEDIATE TRANSACTION`.

### 3.3 macOS Root CA Trust Management
- Privileged helper installation requires `-p ssl -p basic` flags on `security add-trusted-cert`.
- Trust verification uses native `Security.framework` APIs (`SecTrustSettingsCopyTrustSettings`, `SecTrustEvaluateWithError`), avoiding CLI false positives.

### 3.4 Modular Package Architecture
- Packages hierarchy: `KTStackCore` -> `KTPlatformContracts` -> `KTPluginKit` -> Feature Plugins (`KTDumpsPlugin`, `KTMailPlugin`, `KTLogsPlugin`, `KTTunnelPlugin`, `KTDoctorPlugin`, `KTDatabasePlugin`) -> App.
- Feature plugins must **never** import `KTStackKit`.

### 3.5 Native CLI (`kt`) & Stdio MCP Server (`KTCLI`)
- **Native Mach-O CLI**: Built as `kt` via `project.yml`, copied into `KTStack.app/Contents/MacOS/kt`.
- **Local Unix IPC Socket**: Listens at `AppSupportPaths().run.appendingPathComponent("ktstack.sock")` with POSIX `0600` permissions.
- **MCP Server**: Subcommand `kt mcp` runs in persistent stdio mode adhering to Model Context Protocol (2024-11-05), exposing tools for AI Coding Agents (Cursor, Claude Code, Windsurf).
- **Zero Network Egress**: All interactions operate 100% locally on device via stdio and Unix domain sockets.

---

## 4. Operational Invariants & Rules of Engagement

1. **Comment Policy**: Zero comments in code (`//`, `/* */`, `MARK:`, `TODO:`). Self-documenting code only. Rationale belongs in documentation and ADRs.
2. **File Size**: Swift files must not exceed 200 lines. Split into focused submodules with descriptive kebab-case names.
3. **No Mocks or Placeholders**: Implement real, compilable, and executable code.
4. **Git Discipline**: Conventional commit messages (`feat:`, `fix:`, `refactor:`). Branches named `feat/<topic>`. No AI references in commit messages, PR bodies or GitHub comments (no `Co-Authored-By: Claude`, no "Generated with Claude Code"); see `.claude/rules/git-conventions.md`. Never use `chore` or `docs` on files inside `.claude/`.

---

## 5. Standard Verification & Test Commands

```bash
# 1. Regenerate Xcode project whenever project.yml or packages change
xcodegen generate

# 2. Run framework logic tests
xcodebuild -project KTStack.xcodeproj -scheme KTStackKit-Tests -destination 'platform=macOS' test

# 3. Quick local gate (linting + tests)
scripts/ci-local.sh --quick

# 4. Build Release application
xcodebuild -project KTStack.xcodeproj -scheme KTStack -destination 'platform=macOS' -configuration Release build

# 5. Integration test with live services (requires built relocatable binaries)
scripts/integration-test.sh
```

---

## 6. Resumption Protocol for Fresh Sessions

When an AI agent starts or resumes a session:
1. **Read `DOCTRINE.md`**: Understand immutable constraints, clean-room requirements, and comment policy.
2. **Read `CONTINUITY.md`**: Check current ecosystem state, active skills, and established patterns.
3. **Inspect Active Skills**: Invoke `swiftui-pro`, `swiftui-liquid-glass`, or `swiftui-performance-audit` when working on UI and macOS views.
4. **Verify Baseline**: Check `git status` to ensure clean working directory before starting changes.
5. **Deliver & Verify**: Verify code compilability, test coverage, and design token integration before concluding the turn.
