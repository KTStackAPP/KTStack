import SwiftUI
import KTStackKit


struct LogLineRow: View {
    let line: LogLine

    var body: some View {
        HStack(alignment: .top, spacing: KDSpacing.space2) {
            Rectangle().fill(gutterColor).frame(width: 3)
            Text(line.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
        .padding(.trailing, KDSpacing.space2)
    }

    private var gutterColor: Color {
        switch line.severity {
        case .info:    return .clear
        case .warning: return Color.KDStatus.warning
        case .error:   return Color.KDStatus.error
        }
    }

    private var textColor: Color {
        switch line.severity {
        case .info:    return .primary
        case .warning: return Color.KDStatus.warning
        case .error:   return Color.KDStatus.error
        }
    }
}
