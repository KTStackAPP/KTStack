import Combine
import Foundation
import KTPlatformContracts
import KTStackCore

// Plugin sở hữu state Logs; wrap LogTailController và forward objectWillChange để view chỉ
// observe một store. Source list pull-based: recompute lúc activate / mở picker / deep-link.
@MainActor
public final class LogsStore: ObservableObject {
    @Published public private(set) var sources: [LogSource] = []
    @Published public private(set) var selectedID: String?

    public let tail = LogTailController()

    private let context: any LogSourceContextProviding
    private let catalog: LogCatalog
    private var isActive = false
    private var pendingTarget: String?
    private var tailChange: AnyCancellable?

    public init(context: any LogSourceContextProviding, paths: AppSupportPaths = AppSupportPaths()) {
        self.context = context
        catalog = LogCatalog(paths: paths)
        tailChange = tail.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    public func refreshSources() {
        sources = catalog.sources(siteDomains: context.siteDomains, phpVersions: context.phpVersions)
    }

    public func activate() {
        isActive = true
        refreshSources()
        if let target = pendingTarget, sources.contains(where: { $0.id == target }) {
            selectedID = target
        } else if selectedID == nil {
            selectedID = sources.first?.id
        }
        pendingTarget = nil
        tail.select(sources.first { $0.id == selectedID })
    }

    // Đổi tab hoặc đóng window: dừng reader (fix leak, nhất quán Mail M05).
    public func deactivate() {
        isActive = false
        tail.select(nil)
    }

    public func select(_ id: String?) {
        selectedID = id
        tail.select(sources.first { $0.id == id })
    }

    // Deep-link: áp ngay nếu tab đang active, else nhớ để activate() dùng.
    public func show(sourceID: String?) {
        guard isActive else { pendingTarget = sourceID; return }
        refreshSources()
        if let sourceID, sources.contains(where: { $0.id == sourceID }) {
            select(sourceID)
        }
    }
}
