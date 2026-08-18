import SwiftUI

public struct KTDot: View {
    public var color: Color
    public var size: CGFloat = KTMetric.statusDot

    public init(color: Color, size: CGFloat = KTMetric.statusDot) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

public struct KTStatusLabel: View {
    public let running: Bool
    public var runningText: String = "Running"
    public var stoppedText: String = "Stopped"

    public init(running: Bool, runningText: String = "Running", stoppedText: String = "Stopped") {
        self.running = running
        self.runningText = runningText
        self.stoppedText = stoppedText
    }

    public var body: some View {
        HStack(spacing: 7) {
            KTDot(color: running ? KTColor.runDot : KTColor.stopDot)
            Text(running ? runningText : stoppedText)
                .font(.jbMono(13, .medium))
                .foregroundStyle(running ? KTColor.runText : KTColor.stopText)
        }
    }
}

public struct KTOnlineLabel: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 7) {
            KTDot(color: KTColor.runDot, size: 6)
            Text(text)
                .font(KTType.sub)
                .foregroundStyle(KTColor.muted)
        }
    }
}
