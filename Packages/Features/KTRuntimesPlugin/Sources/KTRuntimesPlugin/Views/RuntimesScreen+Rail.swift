import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension RuntimesScreen {
    var railSections: [KTCategoryRailSection<RuntimesCategory>] {
        [
            KTCategoryRailSection(id: "LANGUAGES", items: [
                railItem(.php, summary: vm.railSummary(.php)),
                railItem(.node, summary: vm.railSummary(.node)),
            ]),
            KTCategoryRailSection(id: "WEB SERVER", items: [
                railItem(.nginx, summary: "Bundled", dot: KTColor.runDot),
                railItem(.apache, summary: apacheRailSummary),
            ]),
            KTCategoryRailSection(id: "DATABASES & CACHE", items: ServiceEngine.allCases.map { engine in
                railItem(.engine(engine), summary: engines.railSummary(engine), dot: engineDot(engine))
            }),
        ]
    }

    private func railItem(_ category: RuntimesCategory, summary: String, dot: Color? = nil) -> KTCategoryRailItem<RuntimesCategory> {
        KTCategoryRailItem(
            id: category,
            title: category.title,
            summary: summary,
            systemImage: category.systemImage,
            tint: category.tint,
            dot: dot
        )
    }

    private var apacheRailSummary: String {
        if vm.webEngine.installing { return "Installing…" }
        if vm.webEngine.installed { return vm.webEngine.apacheVersion }
        return "Not installed"
    }

    private func engineDot(_ engine: ServiceEngine) -> Color? {
        guard let snap = engines.snapshot(engine), !snap.installed.isEmpty else { return nil }
        return snap.isRunning ? KTColor.runDot : KTColor.stopDot
    }
}
