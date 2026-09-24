import KTPluginKit
import KTStackKit
import SwiftUI

struct UninstallFlow: ViewModifier {
    @Binding var isConfirming: Bool
    @ObservedObject var uninstaller: UninstallService
    @State private var showProgress = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Uninstall KTStack and remove all data?", isPresented: $isConfirming) {
                Button("Uninstall / Reset", role: .destructive) {
                    showProgress = true
                    uninstaller.uninstall()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This stops all services, removes DNS, CA trust and the helper, and moves app data, runtimes and databases to the Trash.")
            }
            .sheet(isPresented: $showProgress) { UninstallProgressView(uninstaller: uninstaller) { showProgress = false } }
    }
}

struct UninstallProgressView: View {
    @ObservedObject var uninstaller: UninstallService
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(uninstaller.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(KDFont.footnote).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if uninstaller.state == .running { ProgressView().controlSize(.small) }
                Spacer()
                Button("Close", action: onClose).disabled(uninstaller.state == .running)
            }
        }
        .padding(18)
        .frame(width: 460, height: 320)
        .interactiveDismissDisabled(uninstaller.state == .running)
    }

    private var title: String {
        switch uninstaller.state {
        case .idle, .running: "Uninstalling KTStack…"
        case .done: "Uninstall complete. KTStack will quit."
        case let .failed(message): "Uninstall finished with problems: \(message)"
        }
    }
}

extension View {
    func uninstallFlow(isConfirming: Binding<Bool>, uninstaller: UninstallService) -> some View {
        modifier(UninstallFlow(isConfirming: isConfirming, uninstaller: uninstaller))
    }
}
