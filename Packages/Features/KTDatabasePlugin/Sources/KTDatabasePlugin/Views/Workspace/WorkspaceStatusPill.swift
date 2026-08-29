import KTPluginKit
import SwiftUI

/// Pill trạng thái ở giữa toolbar: tag LOCAL/REMOTE, engine + version, DB switcher, khoá đọc/ghi, ping.
struct WorkspaceStatusPill: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let onSelectDatabase: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            tag
            engineText
            if !vm.databases.isEmpty {
                separator
                databasePicker
            }
            separator
            lock
            if let latency = vm.latencyMs {
                separator
                pingText(latency)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(KTEditorTheme.pillBg, in: Capsule())
        .overlay(Capsule().stroke(KTEditorTheme.separator, lineWidth: 1))
    }

    private var isManaged: Bool { vm.activeProfile?.isManaged ?? false }

    private var tag: some View {
        Text(isManaged ? "LOCAL" : "REMOTE")
            .font(.jbMono(9.5, .bold))
            .foregroundStyle(isManaged ? KTEditorTheme.Status.running : KTEditorTheme.label2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isManaged ? KTEditorTheme.Status.running : KTEditorTheme.label2).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    private var engineText: some View {
        Text(engineLabel)
            .font(.jbMono(12.5, .medium))
            .foregroundStyle(KTEditorTheme.label)
    }

    private var engineLabel: String {
        let engine: String
        switch vm.connectionKind {
        case .mysql: engine = "MySQL"
        case .postgres: engine = "PostgreSQL"
        case .sqlite: engine = "SQLite"
        case .mongodb: engine = "MongoDB"
        case nil: engine = "—"
        }
        if let version = vm.serverVersion, !version.isEmpty {
            return "\(engine) \(version)"
        }
        return engine
    }

    private var databasePicker: some View {
        Menu {
            ForEach(vm.databases) { db in
                Button(db.name) { onSelectDatabase(db.name) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cylinder.split.1x2").font(.system(size: 10))
                Text(vm.selectedDatabase ?? "—").font(.jbMono(12.5, .medium))
                Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(KTEditorTheme.label3)
            }
            .foregroundStyle(KTEditorTheme.label)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var lock: some View {
        Image(systemName: vm.connectionIsReadOnly ? "lock.fill" : "lock.open")
            .font(.system(size: 11))
            .foregroundStyle(vm.connectionIsReadOnly ? KTEditorTheme.Status.warning : KTEditorTheme.label3)
    }

    private func pingText(_ ms: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(KTEditorTheme.Status.running).frame(width: 5, height: 5)
            Text(ms <= 0 ? "<1ms" : "\(ms)ms")
                .font(.jbMono(11))
                .foregroundStyle(KTEditorTheme.label2)
        }
    }

    private var separator: some View {
        Rectangle().fill(KTEditorTheme.separator).frame(width: 1, height: 14)
    }
}
