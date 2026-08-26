import SwiftUI

// Modal generic cho child window shell: plugin present nội dung đầy đủ (kể cả chrome riêng), shell
// chỉ render content() không biết type. present cùng id thay modal cũ, không stack.
@MainActor
public final class KTModalPresenter: ObservableObject {
    public struct Modal: Identifiable {
        public let id: String
        public let content: () -> AnyView
    }

    @Published public private(set) var modal: Modal?

    public init() {}

    public func present(id: String, @ViewBuilder content: @escaping () -> some View) {
        modal = Modal(id: id, content: { AnyView(content()) })
    }

    public func dismiss() {
        modal = nil
    }
}
