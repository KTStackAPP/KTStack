import AppKit

extension SitesViewModel {
    // Một lượt tra LaunchServices cho cả list thay vì mỗi row: row của LazyVStack hiện ra
    // lúc đang cuộn, tra cứu đồng bộ trên main thread ở đó làm rớt frame.
    func refreshEditors() {
        let next = CodeEditorCatalog(locate: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        if next.installed != editors.installed { editors = next }
        syncPreferredEditor()
    }

    // Editor ưa thích nằm trong UserDefaults (SiteActions.openInEditor ghi vào đó); giữ bản
    // snapshot ở đây để row `.equatable()` thấy được thay đổi.
    func syncPreferredEditor() {
        let next = editors.preferred()
        if next != preferredEditor { preferredEditor = next }
    }
}
