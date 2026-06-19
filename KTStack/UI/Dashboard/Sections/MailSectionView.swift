import SwiftUI
import KTStackKit

struct MailSectionView: View {
    @EnvironmentObject private var mail: MailStore
    @EnvironmentObject private var services: ServiceManager

    var body: some View {
        Group {
            if !mail.isReachable && mail.messages.isEmpty {
                offlineState
            } else {
                HSplitView {
                    messageList.frame(minWidth: 240, idealWidth: 300)
                    detailPane.frame(minWidth: 360)
                }
            }
        }
        .navigationTitle("Mail")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { mail.deleteAll() } label: { Label("Delete All", systemImage: "trash") }
                    .disabled(mail.messages.isEmpty)
            }
        }
        .onAppear { mail.startPolling() }
        .onDisappear { mail.stopPolling() }
    }

    private var offlineState: some View {
        EmptyStateView(
            symbol: "envelope",
            title: "Mailpit is off",
            message: "Start Mailpit to catch outgoing mail from your sites and read it here.",
            actionTitle: "Start Mailpit"
        ) { services.toggle(.mailpit) }
    }

    private var messageList: some View {
        List(selection: Binding(get: { mail.selectedID }, set: { if let id = $0 { mail.select(id) } })) {
            ForEach(mail.messages) { msg in
                MailRow(summary: msg).tag(msg.ID)
            }
        }
        .overlay {
            if mail.messages.isEmpty {
                Text("No messages yet.\nSend mail from a site to :1025.")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let detail = mail.detail {
            MailMessageView(detail: detail,
                            onDelete: { mail.delete(detail.ID) },
                            rawURL: mail.rawURL(detail.ID))
        } else {
            EmptyStateView(symbol: "envelope.open", title: "No message selected",
                           message: "Pick a message from the list to read it.", actionTitle: nil)
        }
    }
}


private struct MailRow: View {
    let summary: MailSummary

    var body: some View {
        HStack(spacing: KDSpacing.space2) {
            Circle().fill(summary.Read ? Color.clear : Color.accentColor).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(summary.From?.display ?? "—").font(KDFont.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if summary.Attachments > 0 { Image(systemName: "paperclip").font(.system(size: 9)).foregroundStyle(.tertiary) }
                }
                Text(summary.Subject.isEmpty ? "(no subject)" : summary.Subject)
                    .font(KDFont.body).fontWeight(summary.Read ? .regular : .semibold).lineLimit(1)
                if let date = summary.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
