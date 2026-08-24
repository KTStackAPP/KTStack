import SwiftUI

@MainActor
public final class KTFeedbackCenter: ObservableObject {
    public struct ConfirmRequest: Identifiable {
        public let id = UUID()
        public let title: String
        public let message: String
        public let okLabel: String
        public let danger: Bool
        public let onConfirm: () -> Void
    }

    @Published public var toastMessage: String?
    @Published public var confirmRequest: ConfirmRequest?

    private var dismissTask: Task<Void, Never>?

    public init() {}

    public func toast(_ text: String) {
        toastMessage = text
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    public func confirm(
        title: String,
        message: String,
        okLabel: String = "Confirm",
        danger: Bool = true,
        onConfirm: @escaping () -> Void
    ) {
        confirmRequest = ConfirmRequest(
            title: title,
            message: message,
            okLabel: okLabel,
            danger: danger,
            onConfirm: onConfirm
        )
    }
}

public extension View {
    func ktFeedbackHost(_ center: KTFeedbackCenter) -> some View {
        overlay(alignment: .bottom) {
            if let message = center.toastMessage {
                KTToast(message: message)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if let request = center.confirmRequest {
                KTConfirmModal(
                    title: request.title,
                    message: request.message,
                    okLabel: request.okLabel,
                    danger: request.danger,
                    onCancel: { center.confirmRequest = nil },
                    onConfirm: { center.confirmRequest = nil; request.onConfirm() }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: center.toastMessage)
        .animation(.easeOut(duration: 0.15), value: center.confirmRequest?.id)
    }
}
