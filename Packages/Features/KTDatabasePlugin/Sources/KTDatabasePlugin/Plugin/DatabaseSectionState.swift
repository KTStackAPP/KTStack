import SwiftUI

// Chỉ giữ cờ modal để view observe object nhỏ này, không observe cả plugin.
@MainActor
public final class DatabaseSectionState: ObservableObject {
    @Published public var connectPresented = false
    @Published public var newDatabasePresented = false
}
