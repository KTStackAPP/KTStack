import KTPlatformContracts
import KTPluginKit
import SwiftUI

public final class KTMailPlugin: KTStackPlugin, SectionActivationObserving {
    public let descriptor = PluginDescriptor(id: "mail", title: "Mail", systemImage: "envelope")

    private let mailpit: any MailpitProviding
    @MainActor private lazy var store = MailStore(client: MailpitClient(baseURL: mailpit.mailpitAPIBaseURL))

    public init(mailpit: any MailpitProviding) { self.mailpit = mailpit }

    @MainActor public func makeContentView() -> AnyView {
        AnyView(MailSectionView(
            mail: store,
            apiBaseURL: mailpit.mailpitAPIBaseURL,
            startMailpit: { [mailpit] in mailpit.startMailpit() }
        ))
    }

    // Poll chỉ khi tab Mail active và window mở; rời tab hoặc đóng window thì dừng (fix leak).
    @MainActor public func sectionDidActivate() { store.startPolling() }
    @MainActor public func sectionDidDeactivate() { store.stopPolling() }
}
