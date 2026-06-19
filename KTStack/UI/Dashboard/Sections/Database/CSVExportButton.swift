import SwiftUI
import UniformTypeIdentifiers
import KTStackKit

struct CSVExportButton: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    let defaultName: String
    var result: QueryResult? = nil

    var body: some View {
        Button { presentSavePanel() } label: {
            Label("Export CSV…", systemImage: "square.and.arrow.up")
        }
        .disabled(exportResult == nil)
        .help("Export all rows to a .csv file")
    }

    private var exportResult: QueryResult? { result ?? vm.result }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(defaultName).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let exportResult {
            vm.exportResultCSV(exportResult, to: url)
        }
    }
}
