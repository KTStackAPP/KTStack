import KTPluginKit
import SwiftUI

struct BackupDestinationRow: View {
    let destination: BackupDestination
    @ObservedObject var model: BackupDestinationsModel
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        KTSettingsRow(title: destination.name, subtitle: subtitle) {
            HStack(spacing: 8) {
                if model.testing.contains(destination.id) {
                    ProgressView().controlSize(.small)
                } else {
                    KTSettingsTextButton(title: "Test") { Task { await model.test(destination) } }
                }
                KTSettingsTextButton(title: "Edit…", action: onEdit)
                KTSettingsTextButton(title: "Remove…", danger: true, action: onRemove)
            }
        }
    }

    private var subtitle: String {
        var lines = ["\(destination.kind.label) · \(destination.targetDescription)"]
        if destination.kind == .googleDrive, let email = destination.googleDrive?.accountEmail, !email.isEmpty {
            lines[0] += " · \(email)"
        }
        if let test = destination.lastTest {
            let mark = test.succeeded ? "✓" : "✗"
            lines.append("\(mark) \(test.message) (\(BackupFormatting.relative(test.testedAt)))")
        }
        let plans = model.plans(using: destination.id).map(\.name)
        if !plans.isEmpty { lines.append("Used by \(plans.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }
}
