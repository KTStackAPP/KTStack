import Combine
import Foundation
import KTPlatformContracts

// Trạng thái UI chung cho list và inspector; không lưu xuống đĩa.
@MainActor
final class SitesPaneModel: ObservableObject {
    @Published var selectedID: UUID?
    @Published var kindFilter: SiteKind?
    @Published var searchText = ""
    @Published var inspectorVisible = true
    @Published var isActive = false
    @Published private(set) var searchFocusToken = 0

    func focusSearch() {
        searchFocusToken += 1
    }
}
