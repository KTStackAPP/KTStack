import KTStackKit
import SwiftUI

struct KTNodeStatusBadge: View {
    let state: NodeSiteController.State

    var body: some View {
        HStack(spacing: 6) {
            KTDot(color: state.serviceStatus.color, size: 7)
            Text(state.badgeLabel)
                .font(.jbMono(12.5, .medium))
                .foregroundStyle(KTColor.muted)
        }
        .frame(width: 104, alignment: .leading)
    }
}

