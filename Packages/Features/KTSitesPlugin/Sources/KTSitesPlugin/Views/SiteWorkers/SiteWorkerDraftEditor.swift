import KTPluginKit
import KTStackCore
import SwiftUI

struct SiteWorkerDraftEditor: View {
    @ObservedObject var model: SiteWorkersModel
    let current: [SiteWorker]

    var body: some View {
        if let draft = Binding($model.draft) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("name", text: draft.name)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5)).frame(width: 140)
                        .accessibilityLabel("Worker name")
                    TextField("php artisan queue:work", text: draft.command)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                        .accessibilityLabel("Worker command")
                        .onSubmit { model.commitDraft(current: current) }
                }
                HStack(spacing: 10) {
                    Text("A leading “php” runs the site's PHP version.")
                        .font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
                    Spacer()
                    KTButton(title: "Cancel", kind: .link, action: model.cancelDraft)
                    KTButton(title: draft.wrappedValue.editing == nil ? "Add" : "Save", kind: .secondary) {
                        model.commitDraft(current: current)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(KTColor.fieldBg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KTColor.sep, lineWidth: 0.5))
        }
    }
}
