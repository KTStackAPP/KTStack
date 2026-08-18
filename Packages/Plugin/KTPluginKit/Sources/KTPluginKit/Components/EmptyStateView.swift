import SwiftUI

public struct EmptyStateView: View {
    public let symbol: String
    public let title: String
    public let message: String
    public var actionTitle: String?
    public var action: (() -> Void)?

    public init(symbol: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: KDSpacing.space4) {
            Image(systemName: symbol)
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.secondary)
            VStack(spacing: KDSpacing.space2) {
                Text(title).font(KDFont.title)
                Text(message)
                    .font(KDFont.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(KDSpacing.space6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
