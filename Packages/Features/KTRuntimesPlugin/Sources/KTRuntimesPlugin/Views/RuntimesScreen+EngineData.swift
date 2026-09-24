import Foundation
import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension RuntimesScreen {
    @ViewBuilder
    func retiredDataGroup(_ engine: ServiceEngine) -> some View {
        let items = engines.retiredData(engine).filter { matchesFilter($0.version) }
        if !items.isEmpty {
            group("Kept data", count: items.count, isEmpty: false, empty: { EmptyView() }) {
                ForEach(items) { item in
                    RetiredEngineDataRow(
                        item: item,
                        restoreBlockReason: engines.restoreBlockReason(item),
                        onRestore: { requestRestore(item) },
                        onDelete: { requestDeleteData(item) }
                    )
                }
            }
        }
    }

    func requestEngineUninstall(_ engine: ServiceEngine, version: String) {
        Task {
            let footprint = await engines.dataFootprint(engine, version: version)
            feedback.confirm(
                title: "Uninstall \(engine.displayName) \(version)?",
                message: Self.uninstallMessage(engine, version: version, footprint: footprint),
                okLabel: "Uninstall",
                danger: true
            ) {
                performEngineUninstall(engine, version: version)
            }
        }
    }

    func requestRestore(_ item: ServiceEngineRetiredData) {
        feedback.confirm(
            title: "Restore \(item.engine.displayName) \(item.version) data?",
            message: "The kept data at \(item.path) moves back into place for \(item.engine.displayName) \(item.version).",
            okLabel: "Restore",
            danger: false
        ) {
            Task {
                switch await engines.restore(item) {
                case .success: feedback.toast("Restored \(item.engine.displayName) \(item.version) data")
                case let .failure(error): feedback.toast(error.localizedDescription)
                }
            }
        }
    }

    func requestDeleteData(_ item: ServiceEngineRetiredData) {
        let size = ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
        feedback.confirm(
            title: "Delete \(item.engine.displayName) \(item.version) data?",
            message: "Every database in this kept data (\(size)) will no longer be available to KTStack.",
            okLabel: "Continue…",
            danger: true
        ) {
            feedback.confirm(
                title: "Move \(size) to the Trash?",
                message: "\(item.path) moves to the Trash. Empty the Trash to free the space; until then you can put it back.",
                okLabel: "Move to Trash",
                danger: true
            ) {
                performDeleteData(item)
            }
        }
    }

    private func performEngineUninstall(_ engine: ServiceEngine, version: String) {
        Task {
            switch await engines.uninstall(engine, version: version) {
            case let .success(keptAt):
                expandedVersion = nil
                feedback.toast(keptAt == nil ? "Removed \(engine.displayName) \(version)" : "Removed \(engine.displayName) \(version). Data kept.")
            case let .failure(error):
                feedback.toast(error.localizedDescription)
            }
        }
    }

    private func performDeleteData(_ item: ServiceEngineRetiredData) {
        Task {
            switch await engines.trash(item) {
            case .success: feedback.toast("Moved \(item.engine.displayName) \(item.version) data to the Trash")
            case let .failure(error): feedback.toast(error.localizedDescription)
            }
        }
    }

    static func uninstallMessage(_ engine: ServiceEngine, version: String, footprint: ServiceEngineDataFootprint?) -> String {
        let binaries = "The \(engine.displayName) \(version) binaries are removed."
        guard let footprint else { return binaries + " This version has no data." }
        let size = ByteCountFormatter.string(fromByteCount: footprint.sizeBytes, countStyle: .file)
        return binaries + " Its data (\(size) at \(footprint.path)) is kept under .removed and listed as Kept data, "
            + "so you can restore it after reinstalling or delete it later."
    }
}
