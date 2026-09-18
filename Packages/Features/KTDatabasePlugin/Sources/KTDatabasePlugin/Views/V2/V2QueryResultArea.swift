import KTPluginKit
import SwiftUI

struct V2QueryResultArea: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        VStack(spacing: 0) {
            resultsArea
            statusBar
        }
    }

    @ViewBuilder
    private var resultsArea: some View {
        VStack(spacing: 0) {
            if showsResultStrip {
                resultTabsStrip
                Divider().overlay(KTEditorTheme.separator)
            }
            activeResultBody
        }
    }

    private var showsResultStrip: Bool {
        vm.queryResults.count > 1 || vm.queryResults.contains(where: \.isPinned)
    }

    private var resultTabsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(vm.queryResults) { item in
                    resultTabButton(item)
                }
            }
        }
        .frame(height: 28)
        .background(KTEditorTheme.content2)
    }

    private func resultTabButton(_ item: QueryResultItem) -> some View {
        let active = item.id == vm.activeQueryResult?.id
        return HStack(spacing: 6) {
            if item.isPinned {
                Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(KTEditorTheme.label3)
            }
            Text(item.label)
                .font(.system(size: 11))
                .foregroundStyle(active ? KTEditorTheme.label : KTEditorTheme.label2)
                .lineLimit(1)
            Button {
                vm.togglePinResult(id: item.id)
            } label: {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 9)).foregroundStyle(KTEditorTheme.label3)
            }
            .buttonStyle(.plain)
            if vm.queryResults.count > 1 {
                Button {
                    vm.closeResult(id: item.id)
                } label: {
                    Image(systemName: "xmark").font(.system(size: 9)).foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(active ? KTEditorTheme.content : Color.clear)
        .overlay(alignment: .trailing) { Rectangle().fill(KTEditorTheme.separator).frame(width: 1) }
        .contentShape(Rectangle())
        .onTapGesture { vm.selectResult(id: item.id) }
    }

    @ViewBuilder
    private var activeResultBody: some View {
        if let item = vm.activeQueryResult {
            if let result = item.result {
                VStack(spacing: 0) {
                    if item.isTruncatedByCap { fetchAllBar(item) }
                    KTDataGrid(result: result)
                }
            } else if let error = item.error {
                messagePane(error, tint: KTEditorTheme.Status.error, icon: "xmark.circle.fill")
            } else if let notice = item.notice {
                messagePane(notice, tint: KTEditorTheme.label2, icon: "info.circle")
            } else {
                filler
            }
        } else if vm.isRunning {
            VStack { Spacer(); ProgressView(); Spacer() }
                .frame(maxWidth: .infinity)
                .background(KTEditorTheme.content)
        } else {
            filler
        }
    }

    private var filler: some View {
        Spacer().frame(maxWidth: .infinity).background(KTEditorTheme.content)
    }

    private func messagePane(_ text: String, tint: Color, icon: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(text).font(.system(size: 12, design: .monospaced))
            }
            .foregroundStyle(tint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }

    private func fetchAllBar(_ item: QueryResultItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
            Text("Showing first \(SQLAutoLimit.defaultMax) rows.").font(.system(size: 11, design: .monospaced))
            Spacer()
            if item.isFetchingAll {
                ProgressView().controlSize(.small)
            } else {
                V2Button(title: "Fetch All", systemImage: "arrow.down.to.line", kind: .standard) {
                    Task { await vm.fetchAll(resultID: item.id) }
                }
            }
        }
        .foregroundStyle(Color.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            statusContent
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    @ViewBuilder
    private var statusContent: some View {
        if let error = vm.queryError {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                Text(error).font(.system(size: 11, design: .monospaced)).lineLimit(1)
            }
            .foregroundStyle(KTEditorTheme.Status.error)
        } else if let result = vm.queryResult {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                Text("\(result.rowCount) rows").font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(Color.green)
        } else if vm.isRunning {
            ProgressView().scaleEffect(0.7)
        } else {
            Text("Ready").font(.system(size: 11, design: .monospaced)).foregroundStyle(KTEditorTheme.label3)
        }
    }
}
