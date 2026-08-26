import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

extension RuntimesScreen {
    @ViewBuilder
    func categoryPane(_ category: RuntimesCategory) -> some View {
        switch category {
        case .php, .node:
            languageGroups(category.language ?? .php)
        case .nginx, .apache:
            webServerGroup(category)
        case let .engine(engine):
            engineGroups(engine)
        }
    }

    // MARK: PHP / Node

    @ViewBuilder
    private func languageGroups(_ lang: RuntimeLanguage) -> some View {
        let installed = vm.installedEntries(lang).filter { matchesFilter($0.version) }
        let available = vm.availableEntries(lang).filter { matchesFilter($0.version) }
        group("Installed", count: installed.count, isEmpty: installed.isEmpty, empty: {
            EmptyStateView(
                symbol: category(lang).systemImage,
                title: "No \(lang == .php ? "PHP" : "Node") installed yet",
                message: "Pick a version below."
            )
            .frame(minHeight: 140)
        }) {
            ForEach(Array(installed.enumerated()), id: \.element.id) { index, entry in
                installedLanguageRow(lang, entry)
                separator(index, installed.count)
            }
        }
        if !available.isEmpty {
            group("Available", count: available.count, isEmpty: false, empty: { EmptyView() }) {
                ForEach(Array(available.enumerated()), id: \.element.id) { index, entry in
                    availableLanguageRow(lang, entry)
                    separator(index, available.count)
                }
            }
        }
    }

    @ViewBuilder
    private func installedLanguageRow(_ lang: RuntimeLanguage, _ entry: RuntimesViewModel.Entry) -> some View {
        RuntimeVersionRow(
            language: lang,
            version: entry.version,
            isDefault: entry.state == .active,
            isEndOfLife: vm.isEndOfLife(lang, entry.version),
            xdebugOn: lang == .php && phpConfig.isXdebugEnabled(phpVersion: entry.version),
            meta: vm.metaLine(lang, entry),
            isExpanded: expandedVersion == entry.version,
            onSetDefault: {
                vm.setDefault(lang, entry.version)
                feedback.toast("\(lang.displayName) \(entry.version) set as default")
            },
            onToggleInspector: { toggleInspector(entry.version) }
        )
        if expandedVersion == entry.version {
            RuntimeInspectorView(
                version: entry.version,
                language: lang,
                sites: vm.sites(for: entry.version),
                phpConfig: phpConfig,
                onEditIni: { editIni(entry.version) },
                onEditPool: { editPool(entry.version) },
                onManageExtensions: { manageExtensions(entry.version) },
                onUninstall: { requestUninstall(lang, entry.version) }
            )
            .id("\(lang.rawValue)-\(entry.version)")
        }
    }

    private func availableLanguageRow(_ lang: RuntimeLanguage, _ entry: RuntimesViewModel.Entry) -> some View {
        let dl = vm.download(lang, entry.version)
        return AvailableVersionRow(
            title: "\(lang == .php ? "PHP" : "Node") \(entry.version)",
            fraction: dl.flatMap { $0.error == nil ? $0.fraction : nil },
            progressText: dl?.progressText ?? "",
            errorText: dl?.error,
            onInstall: { if let release = entry.release { vm.install(release) } },
            onCancel: { vm.cancel(lang) }
        )
    }

    // MARK: DB / cache engines

    @ViewBuilder
    private func engineGroups(_ engine: ServiceEngine) -> some View {
        let rows = engines.rows(for: engine).filter { matchesFilter($0.version) }
        let installed = rows.filter { $0.state != .available }
        let available = rows.filter { $0.state == .available }
        group("Installed", count: installed.count, isEmpty: installed.isEmpty, empty: {
            EmptyStateView(
                symbol: engine.symbolName,
                title: "No \(engine.displayName) installed yet",
                message: "Pick a version below."
            )
            .frame(minHeight: 140)
        }) {
            ForEach(Array(installed.enumerated()), id: \.element.id) { index, entry in
                installedEngineRow(engine, entry)
                separator(index, installed.count)
            }
        }
        if !available.isEmpty {
            group("Available", count: available.count, isEmpty: false, empty: { EmptyView() }) {
                ForEach(Array(available.enumerated()), id: \.element.id) { index, entry in
                    availableEngineRow(engine, entry)
                    separator(index, available.count)
                }
            }
        }
    }

    @ViewBuilder
    private func installedEngineRow(_ engine: ServiceEngine, _ entry: EngineVersionsViewModel.Entry) -> some View {
        let snap = engines.snapshot(engine)
        let key = "\(engine.rawValue)-\(entry.version)"
        let blockReason = engines.switchBlockReason(engine)
        EngineVersionRow(
            engine: engine,
            version: entry.version,
            isActive: entry.state == .active,
            isRunning: snap?.isRunning ?? false,
            isBusy: snap?.isBusy ?? false,
            meta: engines.metaLine(entry),
            blockReason: blockReason,
            isExpanded: expandedVersion == key,
            onSetActive: { handleSetActive(engine, version: entry.version) },
            onToggleRunning: { engines.toggle(engine) },
            onToggleInspector: { toggleInspector(key) }
        )
        if expandedVersion == key {
            EngineInspectorView(
                engine: engine,
                version: entry.version,
                uninstallBlockReason: blockReason,
                onUninstall: {
                    handleUninstall(engine, version: entry.version)
                    expandedVersion = nil
                }
            )
            .id(key)
        }
    }

    private func availableEngineRow(_ engine: ServiceEngine, _ entry: EngineVersionsViewModel.Entry) -> some View {
        let fraction = entry.release.flatMap { engines.snapshot(engine)?.downloadFraction[$0.id] }
        return AvailableVersionRow(
            title: "\(engine.displayName) \(entry.version)",
            fraction: fraction,
            progressText: fraction.map { "\(Int($0 * 100))%" } ?? "",
            errorText: nil,
            onInstall: { if let release = entry.release { engines.install(release) } },
            onCancel: { if let release = entry.release { engines.cancelInstall(release) } }
        )
    }

    func handleSetActive(_ engine: ServiceEngine, version: String) {
        if case let .failure(error) = engines.setActive(engine, version: version) {
            feedback.toast(error.localizedDescription)
        }
    }

    func handleUninstall(_ engine: ServiceEngine, version: String) {
        if case let .failure(error) = engines.uninstall(engine, version: version) {
            feedback.toast(error.localizedDescription)
        }
    }

    // MARK: Shared

    func group(
        _ label: String,
        count: Int,
        isEmpty: Bool,
        @ViewBuilder empty: () -> some View,
        @ViewBuilder rows: () -> some View
    ) -> some View {
        let content = isEmpty ? AnyView(empty()) : AnyView(VStack(spacing: 0) { rows() })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label).font(.jbMono(12, .bold)).foregroundStyle(KTColor.ink2)
                Text("\(count)").font(KTType.caption).foregroundStyle(KTColor.muted)
            }
            .padding(.leading, 4)
            KTListContainer { content }
        }
    }

    @ViewBuilder
    private func separator(_ index: Int, _ total: Int) -> some View {
        if index < total - 1 {
            Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
        }
    }

    func matchesFilter(_ version: String) -> Bool {
        filter.isEmpty || version.localizedCaseInsensitiveContains(filter)
    }

    private func category(_ lang: RuntimeLanguage) -> RuntimesCategory {
        lang == .php ? .php : .node
    }
}
