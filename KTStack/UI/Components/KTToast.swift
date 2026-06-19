import SwiftUI
import KTStackKit

@MainActor
final class KTToastCenter: ObservableObject {
    @Published var message: String?

    private var dismissTask: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

struct KTToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KTColor.runDot)
            Text(message)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(Capsule().fill(KTColor.ink))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
    }
}

extension View {
    func ktToast(_ center: KTToastCenter) -> some View {
        overlay(alignment: .bottom) {
            if let message = center.message {
                KTToast(message: message)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: center.message)
    }
}
