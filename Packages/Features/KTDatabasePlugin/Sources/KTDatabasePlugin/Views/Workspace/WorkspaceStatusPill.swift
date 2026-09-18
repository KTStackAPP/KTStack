import KTPluginKit
import SwiftUI

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
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
    }

    private var isManaged: Bool { vm.activeProfile?.isManaged ?? false }

    private var tag: some View {
        Text(isManaged ? "LOCAL" : "REMOTE")
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(isManaged ? Color.green : KTEditorTheme.label2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isManaged ? KTEditorTheme.Status.running : KTEditorTheme.label2).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    private var engineText: some View {
        Text(engineLabel)
            .font(.system(size: 12, weight: .medium))
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
                Text(vm.selectedDatabase ?? "—").font(.system(size: 12, weight: .medium))
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
            Circle().fill(Color.green).frame(width: 5, height: 5)
            Text(ms <= 0 ? "<1ms" : "\(ms)ms")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label2)
        }
    }

    private var separator: some View {
        Rectangle().fill(KTEditorTheme.separator).frame(width: 1, height: 14)
    }
}
