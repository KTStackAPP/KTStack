import SwiftUI

/// Chỉ theo dõi state sơ đồ, vm đổi không làm vẽ lại canvas.
struct V2ERCanvas: View {
    @ObservedObject var state: ERDiagramState

    var body: some View {
        Canvas { context, _ in
            var ctx = context
            ctx.translateBy(x: state.canvasOffset.x, y: state.canvasOffset.y)
            ctx.scaleBy(x: state.magnification, y: state.magnification)
            EREdgeRenderer.drawEdges(context: ctx, edges: state.graph.edges, rects: state.cachedRects)
            for node in state.graph.nodes {
                guard let rect = state.cachedRects[node.id] else { continue }
                ERNodeRenderer.drawNode(
                    context: &ctx,
                    node: node,
                    rect: rect,
                    isSelected: state.selectedTable == node.id
                )
            }
        }
    }
}
