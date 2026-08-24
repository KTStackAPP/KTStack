import KTPluginKit
import SwiftUI

struct LogsSectionView: View {
    @ObservedObject var store: LogsStore
    @State private var pickerOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bottomID = "logs-bottom-anchor"

    private var currentSourceName: String {
        store.sources.first { $0.id == store.selectedID }?.displayName ?? "All sites"
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            logPanel.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 16).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .sheet(isPresented: $pickerOpen) {
            KTLogSourcePicker(
                sources: store.sources,
                selectedID: Binding(get: { store.selectedID }, set: { store.select($0) })
            ) { pickerOpen = false }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Text("Logs").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            Spacer()
            sourceMenu
            Button(action: { store.tail.clear() }) {
                Text("Clear").font(.jbMono(13, .medium)).foregroundStyle(KTColor.ink)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(KTColor.btnBorder, lineWidth: 0.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            followToggle
        }
    }

    private var sourceMenu: some View {
        Button { store.refreshSources(); pickerOpen = true } label: {
            KTDropdownChevronLabel(text: currentSourceName)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var followToggle: some View {
        Button(action: { store.tail.isLive.toggle() }) {
            HStack(spacing: 7) {
                if store.tail.isLive {
                    Circle().fill(KTColor.runDot).frame(width: 7, height: 7)
                    Text("Following").font(.jbMono(13, .regular)).foregroundStyle(KTColor.online)
                } else {
                    Image(systemName: "pause.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(KTColor.ink3)
                    Text("Paused").font(.jbMono(13, .medium)).foregroundStyle(KTColor.ink2)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(store.tail.isLive ? KTColor.onlineBg : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(store.tail.isLive ? Color.clear : KTColor.btnBorder, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var logPanel: some View {
        if store.sources.isEmpty {
            emptyPanel("No logs yet", "Start a service to produce logs, then pick a source to tail it here.")
        } else if store.tail.lines.isEmpty {
            emptyPanel("No lines", "This log is empty or filtered out. New lines stream in live.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.tail.lines) { line in logRow(line) }
                        Color.clear.frame(height: 1).id(bottomID)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(KTColor.editorBg))
                .onChange(of: store.tail.lines.count) { _ in
                    guard store.tail.isLive else { return }
                    if reduceMotion { proxy.scrollTo(bottomID, anchor: .bottom) }
                    else { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(bottomID, anchor: .bottom) } }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func logRow(_ line: LogLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(severityLabel(line.severity))
                .font(.jbMono(10, .bold))
                .foregroundStyle(severityColor(line.severity))
                .frame(width: 42, alignment: .leading)
            Text(line.text)
                .font(.jbMono(12.5))
                .foregroundStyle(Color(hex: 0xD4D4DA))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func severityLabel(_ severity: LogSeverity) -> String {
        switch severity {
        case .info: "INFO"
        case .warning: "WARN"
        case .error: "ERROR"
        }
    }

    private func severityColor(_ severity: LogSeverity) -> Color {
        switch severity {
        case .info: Color(hex: 0x7FD4A0)
        case .warning: Color(hex: 0xFFD479)
        case .error: Color(hex: 0xFF8FB0)
        }
    }

    private func emptyPanel(_ title: String, _ message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "text.alignleft").font(.system(size: 42, weight: .light)).foregroundStyle(KTColor.faint)
            Text(title).font(.jbMono(16, .regular)).foregroundStyle(KTColor.ink3)
            Text(message).font(.jbMono(13)).foregroundStyle(KTColor.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
