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
        let local = isManaged
        return Text(local ? "LOCAL" : "REMOTE")
            .font(.caption2.bold().monospaced())
            .foregroundStyle(local ? Color.green : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (local ? Color.green : Color.secondary).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }

    private var engineText: some View {
        Text(engineLabel)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
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
                Image(systemName: "cylinder.split.1x2").font(.caption2)
                Text(vm.selectedDatabase ?? "—").font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var lock: some View {
        Image(systemName: vm.connectionIsReadOnly ? "lock.fill" : "lock.open")
            .font(.caption)
            .foregroundStyle(lockColor)
    }

    private var lockColor: Color {
        vm.connectionIsReadOnly ? .orange : Color(nsColor: .tertiaryLabelColor)
    }

    private func pingText(_ ms: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color.green).frame(width: 5, height: 5)
            Text(ms <= 0 ? "<1ms" : "\(ms)ms")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var separator: some View {
        Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1, height: 14)
    }
}
