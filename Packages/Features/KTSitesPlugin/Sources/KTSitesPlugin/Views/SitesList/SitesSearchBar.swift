import KTPluginKit
import SwiftUI

struct SitesSearchBar: View {
    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel

    @FocusState private var focused: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                field.frame(minWidth: 220)
                chips
            }
            VStack(alignment: .leading, spacing: 10) {
                field
                chips
            }
        }
        .onChange(of: pane.searchFocusToken) { _ in
            // FocusState có thể lệch khi focus đang ở hosting view khác, nên đặt lại.
            focused = false
            DispatchQueue.main.async { focused = true }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(KTColor.muted)
            TextField("Search name, domain, PHP version…", text: $pane.searchText)
                .textFieldStyle(.plain)
                .font(.jbMono(12.5))
                .focused($focused)
                .accessibilityLabel("Search sites")
            Text("⌘F")
                .font(.jbMono(11))
                .foregroundStyle(KTColor.muted)
                .padding(.horizontal, 5)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(KTColor.sep, lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KTColor.fieldBg))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(focused ? KTColor.accent : KTColor.sep, lineWidth: 1)
        )
    }

    private var chips: some View {
        SitesKindChips(
            selection: $pane.kindFilter,
            counts: SitesFilter.counts(vm.sites, query: pane.searchText)
        )
        .fixedSize()
    }
}
