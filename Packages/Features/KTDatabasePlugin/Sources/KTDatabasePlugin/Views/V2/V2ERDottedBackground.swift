import KTPluginKit
import SwiftUI

struct V2ERDottedBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 22
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                        with: .color(Color(nsColor: .separatorColor))
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .drawingGroup()
        .background(KTEditorTheme.content)
    }
}
