import KTPlatformContracts
import KTPluginKit
import SwiftUI

@MainActor
final class XdebugToggleModel: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var supported = false
    @Published private(set) var busy = false
    @Published var error: String?

    let version: String
    let clientPort: Int
    private let phpConfig: any PHPExtensionManaging

    init(version: String, phpConfig: any PHPExtensionManaging) {
        self.version = version
        self.phpConfig = phpConfig
        clientPort = phpConfig.xdebugClientPort
        supported = phpConfig.isXdebugSupported(phpVersion: version)
        enabled = phpConfig.isXdebugEnabled(phpVersion: version)
    }

    func toggle(_ on: Bool) {
        guard !busy, supported else { return }
        busy = true
        error = nil
        Task {
            do { try await phpConfig.setXdebug(on, phpVersion: version) }
            catch { self.error = error.localizedDescription }
            enabled = phpConfig.isXdebugEnabled(phpVersion: version)
            busy = false
        }
    }
}

struct XdebugToggleView: View {
    @StateObject private var model: XdebugToggleModel

    init(version: String, phpConfig: any PHPExtensionManaging) {
        _model = StateObject(wrappedValue: XdebugToggleModel(version: version, phpConfig: phpConfig))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space1) {
            Toggle(isOn: Binding(get: { model.enabled }, set: { model.toggle($0) })) {
                HStack {
                    Text("Xdebug").font(KDFont.body)
                    KTBadge(text: model.enabled ? "on" : "off", tint: badgeTint, radius: 20)
                }
            }
            .disabled(!model.supported || model.busy)

            if !model.supported {
                Text("Not available for PHP \(model.version) on this platform.")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            } else {
                Text("Step debugger on port \(model.clientPort). Toggling restarts PHP \(model.version); sites on this version blip briefly.")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
            }
        }
    }

    private var badgeTint: KTTint {
        model.enabled
            ? KTTint(fg: KTColor.online, bg: KTColor.onlineBg)
            : KTTint(fg: KTColor.muted, bg: KTColor.pillBg)
    }
}
