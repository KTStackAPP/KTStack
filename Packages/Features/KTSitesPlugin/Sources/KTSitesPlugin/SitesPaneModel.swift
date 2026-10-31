import Combine
import Foundation
import KTPlatformContracts

// Trạng thái UI chung cho list và inspector; không lưu xuống đĩa.
@MainActor
final class SitesPaneModel: ObservableObject {
    @Published var selectedID: UUID?
    @Published var kindFilter: SiteKind?
    @Published var groupFilter: GroupFilter = .all
    @Published var searchText = ""
    @Published var inspectorVisible = true
    @Published var isActive = false
    @Published private(set) var searchFocusToken = 0
    // Site đang chờ inspector mở ô nhập nhóm mới; inspector xóa khi đã mở.
    @Published var pendingNewGroup: UUID?

    func focusSearch() {
        searchFocusToken += 1
    }

    // Chọn site rồi mở ô "New Group" trong inspector.
    func requestNewGroup(for id: UUID) {
        selectedID = id
        inspectorVisible = true
        pendingNewGroup = id
    }
}
