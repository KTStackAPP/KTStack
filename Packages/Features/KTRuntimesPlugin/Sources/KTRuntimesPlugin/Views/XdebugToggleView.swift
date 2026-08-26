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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Xdebug").font(KTType.body).foregroundStyle(KTColor.ink)
                KTBadge(text: model.enabled ? "on" : "off", tint: badgeTint, radius: 20)
                Spacer(minLength: 8)
                if model.busy {
                    ProgressView().controlSize(.small)
                } else {
                    KTToggle(isOn: model.enabled) { model.toggle(!model.enabled) }
                        .opacity(model.supported ? 1 : 0.4)
                        .allowsHitTesting(model.supported)
                }
            }
            Text(helpText).font(KTType.caption).foregroundStyle(KTColor.muted)
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KTType.caption).foregroundStyle(KTColor.danger)
            }
        }
    }

    private var helpText: String {
        model.supported
            ? "Step debugger on port \(model.clientPort). Toggling restarts PHP \(model.version); sites on this version blip briefly."
            : "Not available for PHP \(model.version) on this platform."
    }

    private var badgeTint: KTTint {
        model.enabled
            ? KTTint(fg: KTColor.online, bg: KTColor.onlineBg)
            : KTTint(fg: KTColor.muted, bg: KTColor.pillBg)
    }
}
