import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct SiteWorkersSection: View {
    let siteID: UUID
    @ObservedObject var vm: SitesViewModel
    @StateObject private var model: SiteWorkersModel

    init(siteID: UUID, vm: SitesViewModel) {
        self.siteID = siteID
        _vm = ObservedObject(wrappedValue: vm)
        _model = StateObject(wrappedValue: SiteWorkersModel(save: { try vm.setWorkers(siteID, $0) }))
    }

    private var site: SiteSummary? {
        vm.sites.first { $0.id == siteID }
    }

    private var workers: [SiteWorker] {
        site?.workers ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORKERS")
                .font(KTType.sectionLabel)
                .tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.faint)
            ForEach(workers) { worker in
                if model.draft?.editing == worker.id {
                    SiteWorkerDraftEditor(model: model, current: workers)
                } else {
                    SiteWorkerRow(
                        worker: worker,
                        status: vm.workerStatus(worker),
                        actions: actions(for: worker)
                    )
                }
            }
            if let draft = model.draft, draft.editing == nil {
                SiteWorkerDraftEditor(model: model, current: workers)
            }
            footer
            if let error = model.error {
                Text(error).font(.jbMono(12)).foregroundStyle(KTColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(hint).font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            KTButton(title: "Add worker", systemImage: "plus", kind: .link) { model.beginAdd(current: workers) }
                .disabled(model.draft != nil || workers.count >= SiteWorkers.maxPerSite)
            ForEach(model.presets(isLaravel: site.map(vm.isLaravel) ?? false, current: workers), id: \.self) { preset in
                KTButton(title: "Laravel \(preset.title.lowercased())", systemImage: "bolt", kind: .link) {
                    model.add(preset, current: workers)
                }
                .disabled(workers.count >= SiteWorkers.maxPerSite)
            }
            Spacer(minLength: 0)
        }
    }

    private var hint: String {
        let php = site.map { "PHP \($0.phpVersion)" } ?? "the site's PHP"
        return "Long-running commands such as queue:work or schedule:work. They run with \(php), the site folder and its "
            + "environment variables while the server is running, restart with backoff if they crash, and log to Logs. "
            + "Workers never start until you press Start."
    }

    private func actions(for worker: SiteWorker) -> SiteWorkerRow.Actions {
        SiteWorkerRow.Actions(
            start: { vm.startWorker(siteID, worker) },
            stop: { vm.stopWorker(siteID, worker) },
            restart: { vm.restartWorker(siteID, worker) },
            logs: { vm.openWorkerLogs(siteID, worker) },
            edit: { model.beginEdit(worker) },
            remove: { model.remove(worker, current: workers) }
        )
    }
}
