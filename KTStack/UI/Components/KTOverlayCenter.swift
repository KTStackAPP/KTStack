import KTPluginKit
import KTStackKit
import SwiftUI

@MainActor
final class KTOverlayCenter: ObservableObject {
    let feedback = KTFeedbackCenter()

    @Published var newSitePresented = false
    @Published var apiTesterSite: Site?

    var anyModalPresented: Bool {
        newSitePresented || apiTesterSite != nil
    }

    func toast(_ text: String) {
        feedback.toast(text)
    }

    func confirm(
        title: String,
        message: String,
        okLabel: String = "Confirm",
        danger: Bool = true,
        onConfirm: @escaping () -> Void
    ) {
        feedback.confirm(title: title, message: message, okLabel: okLabel, danger: danger, onConfirm: onConfirm)
    }
}

extension View {
    func ktOverlayHost(_ center: KTOverlayCenter) -> some View {
        ktFeedbackHost(center.feedback)
    }
}
