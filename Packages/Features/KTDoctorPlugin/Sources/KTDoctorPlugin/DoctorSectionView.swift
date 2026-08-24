import KTPluginKit
import SwiftUI

struct DoctorSectionView: View {
    @ObservedObject var model: DoctorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            Text("Read-only checks of the pieces that break first: helper, DNS, TLS, ports, binaries.")
                .font(.jbMono(13.5)).foregroundStyle(Color(hex: 0x8E8E93))
                .padding(.horizontal, KTSpacing.screenGutter).padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let report = model.report {
                        summary(report)
                        KTListContainer { rows(report.checks) }
                    } else {
                        EmptyStateView(
                            symbol: "stethoscope",
                            title: model.isRunning ? "Running checks…" : "No results yet",
                            message: model.isRunning
                                ? "Probing the helper, DNS, ports and staged binaries."
                                : "Run the checks to see what needs attention."
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .task { await model.run() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Doctor").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            Spacer()
            KTButton(
                title: model.didCopy ? "Copied" : "Copy report",
                systemImage: model.didCopy ? "checkmark" : "doc.on.doc",
                kind: .secondary
            ) { model.copyReport() }
                .disabled(model.report == nil)
            KTButton(title: "Run checks", kind: .primary, isLoading: model.isRunning) {
                Task { await model.run() }
            }
        }
    }

    private func summary(_ report: DoctorReport) -> some View {
        let failing = report.failures.count
        return HStack(spacing: 8) {
            KTDot(color: Self.color(for: report.status))
            Text(
                failing == 0
                    ? "All \(report.checks.count) checks pass."
                    : "\(failing) of \(report.checks.count) checks need attention."
            )
            .font(KTType.body).foregroundStyle(KTColor.ink2)
            Spacer()
            Text("\(Self.ranAt.string(from: report.generatedAt)) · KTStack \(report.environment.appVersion) · macOS \(report.environment.systemVersion) · \(report.environment.architecture)")
                .font(KTType.sub).foregroundStyle(KTColor.muted)
        }
        .padding(.bottom, 12)
    }

    private func rows(_ checks: [DoctorCheck]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                row(check)
                if index < checks.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    private func row(_ check: DoctorCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            KTDot(color: Self.color(for: check.status)).padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title).font(KTType.rowName).foregroundStyle(KTColor.ink)
                Text(check.detail).font(KTType.sub13).foregroundStyle(KTColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                if let remedy = check.remedy {
                    Text(remedy).font(KTType.sub).foregroundStyle(KTColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if let action = check.action {
                KTButton(title: Self.actionTitle(action), kind: .secondary) { model.perform(action) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
    }

    private static func actionTitle(_ action: DoctorRemedyAction) -> String {
        switch action {
        case .openLoginItems: "Login Items"
        case .openServices: "Services"
        case .openSettings: "Settings"
        case .openRuntimes: "Runtimes"
        }
    }

    /// Màn hình được giữ sống và chỉ ẩn/hiện, nên .task chỉ chạy một lần: hiện giờ chạy để
    /// người dùng biết kết quả cũ tới đâu.
    private static let ranAt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func color(for status: DoctorStatus) -> Color {
        switch status {
        case .pass: Color.KDStatus.running
        case .warn: Color.KDStatus.warning
        case .fail: Color.KDStatus.error
        }
    }
}
