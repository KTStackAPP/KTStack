import SwiftUI
import AppKit
import KTStackKit


struct MailMessageView: View {
    let detail: MailDetail
    let onDelete: () -> Void
    let rawURL: URL

    private enum Tab: String, CaseIterable { case plain = "Plain", html = "HTML" }
    @State private var tab: Tab = .plain

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            bodyContent
            if let attachments = detail.Attachments, !attachments.isEmpty {
                Divider()
                attachmentsList(attachments)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail.Subject.isEmpty ? "(no subject)" : detail.Subject)
                .font(KDFont.title).lineLimit(2)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("From: \(detail.From?.display ?? "—")").font(KDFont.footnote).foregroundStyle(.secondary)
                    Text("To: \((detail.To ?? []).map(\.display).joined(separator: ", "))")
                        .font(KDFont.footnote).foregroundStyle(.secondary).lineLimit(1)
                    if let date = detail.date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(KDFont.footnote).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button { NSWorkspace.shared.open(rawURL) } label: { Label("Raw", systemImage: "doc.plaintext") }
                    .controlSize(.small)
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                    .controlSize(.small)
            }
        }
        .padding(KDSpacing.space3)
    }

    private var tabBar: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { t in
                // Only offer HTML when the message actually has an HTML part.
                if t == .plain || (detail.HTML?.isEmpty == false) { Text(t.rawValue).tag(t) }
            }
        }
        .pickerStyle(.segmented).labelsHidden().fixedSize()
        .padding(.horizontal, KDSpacing.space3).padding(.vertical, KDSpacing.space2)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch tab {
        case .html where (detail.HTML?.isEmpty == false):
            MailHTMLView(html: detail.HTML ?? "")
        default:
            ScrollView {
                Text(detail.Text ?? detail.HTML?.strippingTags ?? "(empty)")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(KDSpacing.space3)
            }
        }
    }

    private func attachmentsList(_ attachments: [MailAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Attachments (\(attachments.count))").font(KDFont.footnote).foregroundStyle(.secondary)
            ForEach(attachments) { a in
                HStack(spacing: KDSpacing.space2) {
                    Image(systemName: "paperclip").foregroundStyle(.secondary)
                    Text(a.FileName).font(KDFont.footnote)
                    Text(ByteCountFormatter().string(fromByteCount: Int64(a.Size)))
                        .font(KDFont.footnote).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(KDSpacing.space3)
    }
}

private extension String {

    var strippingTags: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
