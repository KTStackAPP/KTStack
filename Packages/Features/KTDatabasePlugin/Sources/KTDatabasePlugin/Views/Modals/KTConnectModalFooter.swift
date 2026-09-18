import KTPluginKit
import SwiftUI

struct KTConnectModalFooter: View {
    let testing: Bool
    let isValid: Bool
    let tested: Bool
    let testError: String?
    let onRunTest: () -> Void
    let onClose: () -> Void
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onRunTest) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .medium))
                    Text("Test Connection").font(.system(size: 12.5, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(testing || !isValid)
            testStatus.padding(.leading, 12).layoutPriority(-1)
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                Button("Cancel", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.cancelAction)
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider().overlay(Color(nsColor: .separatorColor)) }
    }

    @ViewBuilder
    private var testStatus: some View {
        if testing {
            ProgressView().controlSize(.small)
        } else if let error = testError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(nsColor: .systemRed))
                .lineLimit(1)
        } else if tested {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                Text("Connection successful")
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(nsColor: .systemGreen))
        }
    }
}
