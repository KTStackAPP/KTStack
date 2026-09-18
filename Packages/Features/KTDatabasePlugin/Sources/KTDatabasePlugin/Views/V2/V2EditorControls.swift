import KTPluginKit
import SwiftUI

enum V2ButtonKind {
    case primary
    case standard
    case danger
}

struct V2Button: View {
    let title: String
    var systemImage: String?
    var kind: V2ButtonKind = .standard
    var action: (() -> Void)?

    var body: some View {
        Group {
            switch kind {
            case .primary:
                Button {
                    action?()
                } label: {
                    buttonLabel
                }
                .buttonStyle(.borderedProminent)
            case .standard:
                Button {
                    action?()
                } label: {
                    buttonLabel
                }
                .buttonStyle(.bordered)
            case .danger:
                Button(role: .destructive) {
                    action?()
                } label: {
                    buttonLabel
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.small)
    }

    private var buttonLabel: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
            }
            Text(title)
                .font(.system(size: 12, weight: kind == .primary ? .semibold : .regular))
        }
    }
}

struct V2IconButton: View {
    let systemImage: String
    var tint: Color = Color(nsColor: .secondaryLabelColor)
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(tint)
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
