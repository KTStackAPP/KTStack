import KTPluginKit
import SwiftUI

extension SiteListRow {
    var nodeRoute: some View {
        HStack(spacing: 4) {
            Text("→ localhost:").font(.jbMono(12.5)).foregroundStyle(KTColor.faint)
            nodePortField
        }
    }

    @ViewBuilder
    var nodeStatusControl: some View {
        Group {
            if nodeRunning {
                KTOnlineLabel(text: "live")
            } else if site.nodePort != nil {
                KTButton(title: "Start", kind: .secondary) { SiteActions.startNodeInTerminal(site) }
                    .ktTip("Open Terminal at the project with PORT set; run your dev server there")
            } else {
                Text("set a port").font(.jbMono(12)).foregroundStyle(KTColor.faint)
            }
        }
        .frame(width: 104, alignment: .leading)
    }

    var nodePortField: some View {
        TextField("port", text: $nodePortDraft)
            .textFieldStyle(.plain)
            .font(.jbMono(12.5))
            .foregroundStyle(KTColor.ink)
            .frame(width: 46)
            .multilineTextAlignment(.center)
            .padding(.vertical, 2).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(KTColor.pillBg))
            .onSubmit(saveNodePort)
            .ktTip("Port your Node app listens on; KTStack proxies this site to it")
            .accessibilityLabel("Node port for \(site.domain)")
    }

    func saveNodePort() {
        let trimmed = nodePortDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? onSetNodePort(nil)
            return
        }
        guard let port = Int(trimmed), (1 ... 65535).contains(port) else {
            nodePortDraft = site.nodePort.map(String.init) ?? ""
            onError("Enter a port between 1 and 65535.")
            return
        }
        do {
            try onSetNodePort(port)
        } catch {
            nodePortDraft = site.nodePort.map(String.init) ?? ""
            onError(error.localizedDescription)
        }
    }
}
