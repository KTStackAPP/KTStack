import SwiftUI
import KTStackKit

struct DatabaseWindow: View {
    static let windowID = "database-browser"

    var body: some View {
        DatabaseSectionView(inWindow: true)
            .frame(minWidth: 900, minHeight: 540)
    }
}
