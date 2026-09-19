import KTPluginKit
import KTStackCore
import KTStackKit
import SwiftUI

@MainActor
final class ShellIntegrationModel: ObservableObject {
    @Published private(set) var status: ShellPathManager.Status
    @Published private(set) var busy = false
    @Published private(set) var composerWarning = false
    @Published var errorText: String?
    @Published var expandedSuites: Set<ShellToolSuite> = Set(ShellToolSuite.allCases)

    private let manager: ShellPathManager

    init() {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ktstack-resolve")
        manager = ShellPathManager(paths: AppSupportPaths(), helperSource: helper)
        status = manager.status()
    }

    func setMasterEnabled(_ enabled: Bool) {
        guard !busy else { return }
        busy = true
        errorText = nil
        Task {
            do {
                if enabled { try await manager.enable() } else { try manager.disable() }
            } catch {
                errorText = error.localizedDescription
            }
            status = manager.status()
            composerWarning = status.enabled && !manager.composerProvisioned()
            busy = false
        }
    }

    func setToolEnabled(_ toolId: String, enabled: Bool) {
        do {
            try manager.setToolEnabled(toolId, enabled: enabled)
            status = manager.status()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func setSuiteEnabled(_ suite: ShellToolSuite, enabled: Bool) {
        do {
            try manager.setSuiteEnabled(suite, enabled: enabled)
            status = manager.status()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func isSuiteEnabled(_ suite: ShellToolSuite) -> Bool {
        let tools = ShellToolCatalog.tools(for: suite)
        let installed = tools.filter { status.isToolInstalled($0.id) }
        guard !installed.isEmpty else { return false }
        return installed.allSatisfy { status.isToolEnabled($0.id) }
    }

    func reapply() {
        setMasterEnabled(true)
    }
}

struct ShellIntegrationView: View {
    @StateObject private var model = ShellIntegrationModel()

    var body: some View {
        Section("Shell PATH") {
            Toggle("Add KTStack tools to shell PATH", isOn: Binding(
                get: { model.status.enabled },
                set: { model.setMasterEnabled($0) }
            ))
            .disabled(model.busy)

            Text("Opens a managed PATH block in ~/.zshrc (and bash if present). Changes to individual tools hot-reload instantly in open terminals.")
                .font(KDFont.footnote).foregroundStyle(.secondary)

            if model.busy {
                Label("Applying…", systemImage: "arrow.triangle.2.circlepath").font(KDFont.footnote)
            }

            if !model.status.shellsPatched.isEmpty {
                Label("Patched: \(model.status.shellsPatched.joined(separator: ", "))", systemImage: "checkmark.circle")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
                Button("Re-apply") { model.reapply() }.disabled(model.busy)
            }

            if model.composerWarning {
                Label(
                    "Composer download didn't finish — the composer command won't work yet. Re-apply to retry.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(KDFont.footnote).foregroundStyle(.orange)
            }

            if let errorText = model.errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(.red)
            }
        }

        if model.status.enabled {
            Section("Managed Tools") {
                ForEach(ShellToolSuite.allCases) { suite in
                    ShellSuiteSectionView(
                        suite: suite,
                        tools: ShellToolCatalog.tools(for: suite),
                        isSuiteEnabled: model.isSuiteEnabled(suite),
                        isToolEnabled: { model.status.isToolEnabled($0) },
                        isToolInstalled: { model.status.isToolInstalled($0) },
                        onToggleSuite: { model.setSuiteEnabled(suite, enabled: $0) },
                        onToggleTool: { model.setToolEnabled($0, enabled: $1) },
                        isExpanded: Binding(
                            get: { model.expandedSuites.contains(suite) },
                            set: {
                                if $0 { model.expandedSuites.insert(suite) }
                                else { model.expandedSuites.remove(suite) }
                            }
                        )
                    )
                }
            }
        }
    }
}
