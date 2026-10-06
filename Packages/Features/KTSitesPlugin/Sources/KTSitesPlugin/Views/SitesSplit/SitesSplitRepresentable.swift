import SwiftUI

struct SitesSplitRepresentable: NSViewControllerRepresentable {
    let pane: SitesPaneModel
    let list: AnyView
    let inspector: AnyView

    func makeNSViewController(context _: Context) -> SitesSplitController {
        SitesSplitController(pane: pane, list: list, inspector: inspector)
    }

    // Hai pane tự observe model, không cần đẩy lại view.
    func updateNSViewController(_: SitesSplitController, context _: Context) {}
}
