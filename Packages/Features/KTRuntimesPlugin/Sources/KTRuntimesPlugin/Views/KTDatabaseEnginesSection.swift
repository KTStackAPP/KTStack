import KTPlatformContracts
import KTPluginKit
import SwiftUI

// DB và cache engine là runtime on-demand như PHP/Node nên UI install/switch/run nằm cùng Runtimes,
// không dưới Services. State đến từ ServiceEngineVersionManaging (snapshot stream).
struct KTDatabaseEnginesSection: View {
    @ObservedObject var engines: EngineVersionsViewModel
    @EnvironmentObject private var feedback: KTFeedbackCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATABASES & CACHE")
                .font(KTType.sectionLabel).tracking(KTType.sectionLabelTracking).foregroundStyle(KTColor.faint)
                .padding(.leading, 4)
            Text("Install and run bundled engines. Data is stored separately per version.")
                .font(KTType.sub).foregroundStyle(KTColor.muted).padding(.leading, 4)
            KTListContainer { rows }
        }
    }

    private var rows: some View {
        let items = engines.rows
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                let engine = entry.engine
                let snap = engines.snapshot(engine)
                let isEngineActive = snap?.isRunning == true || snap?.isBusy == true
                EngineVersionRow(
                    engine: engine,
                    version: entry.version,
                    state: entry.state,
                    isEngineRunning: isEngineActive,
                    isRunning: snap?.isRunning ?? false,
                    isBusy: snap?.isBusy ?? false,
                    downloadFraction: entry.release.flatMap { snap?.downloadFraction[$0.id] },
                    isSwitchOrInstallInFlight: snap?.installInFlight ?? false,
                    onSetActive: { handleSetActive(engine, version: entry.version) },
                    onToggleRunning: { engines.toggle(engine) },
                    onInstall: { if let release = entry.release { engines.install(release) } },
                    onCancel: { if let release = entry.release { engines.cancelInstall(release) } },
                    onUninstall: { handleUninstall(engine, version: entry.version) }
                )
                if index < items.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    private func handleSetActive(_ engine: ServiceEngine, version: String) {
        if case let .failure(error) = engines.setActive(engine, version: version) {
            feedback.toast(error.localizedDescription)
        }
    }

    private func handleUninstall(_ engine: ServiceEngine, version: String) {
        if case let .failure(error) = engines.uninstall(engine, version: version) {
            feedback.toast(error.localizedDescription)
        }
    }
}
