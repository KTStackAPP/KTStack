import AppKit
import KTPluginKit
import KTStackKit
import SwiftUI

extension SettingsView {
    func sheetWrapper(
        _ title: String,
        _ onDone: @escaping () -> Void,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.jbMono(15, .regular)).foregroundStyle(KTColor.ink)
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            Divider()
            content()
        }
        .frame(width: 540, height: 480)
    }

    var appearanceMenu: some View {
        KTDropdown(
            width: 140,
            options: AppPreferences.Appearance.allCases.map { appearance in
                KTDropdownOption(label: appearance.label, active: appearance == preferences.appearance) {
                    preferences.appearance = appearance
                    AppAppearance.apply(appearance)
                }
            }
        ) {
            KTDropdownChevronLabel(text: preferences.appearance.label)
        }
        .fixedSize()
    }
}

struct ShellIntegrationSheetBody: View {
    var body: some View {
        Form { ShellIntegrationView() }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(KTColor.contentBg)
    }
}
