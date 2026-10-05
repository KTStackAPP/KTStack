import KTPlatformContracts

// Các hành động mở sheet hoặc toast nằm ở SitesScreen, inspector chỉ gọi lại.
struct SiteInspectorActions {
    let openLogs: (SiteSummary) -> Void
    let toggleShare: (SiteSummary, Bool) -> Void
    let recheckType: (SiteSummary) -> Void
    let configureVSCode: (SiteSummary) -> Void
    let restore: (SiteSummary) -> Void
    let remove: (SiteSummary) -> Void
    let reportError: (String) -> Void
}
