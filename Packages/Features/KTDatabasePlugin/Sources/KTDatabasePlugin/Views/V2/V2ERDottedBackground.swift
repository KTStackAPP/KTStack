import KTPluginKit
import SwiftUI

struct V2ERDottedBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 22
            var dots = Path()
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
                    x += spacing
                }
                y += spacing
            }
            ctx.fill(dots, with: .color(Color(nsColor: .separatorColor)))
        }
        .drawingGroup()
        .background(KTEditorTheme.content)
    }
}
