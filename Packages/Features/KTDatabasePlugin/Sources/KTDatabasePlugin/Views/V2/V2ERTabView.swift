import AppKit
import KTPluginKit
import SwiftUI

struct V2ERTabView: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @StateObject private var state = ERDiagramState()

    @State private var scrollMonitor: Any?
    @State private var hoverCursor: NSCursor?
    @State private var magnifyStartMag: CGFloat?

    var body: some View {
        Group {
            if vm.isLoadingDiagram {
                centeredView { ProgressView() }
            } else if state.isEmpty {
                placeholder
            } else {
                diagram
            }
        }
        .task(id: vm.selectedDatabase) {
            await vm.loadDiagram()
            syncState()
        }
        .onChange(of: vm.diagramLoaded) { loaded in
            if loaded { syncState() }
        }
        .onAppear { attachScrollMonitor() }
        .onDisappear { detachScrollMonitor() }
    }

    private func syncState() {
        state.apply(
            catalog: vm.schemaCatalog,
            connectionKey: vm.connectionProfileID ?? "v2",
            schemaKey: vm.selectedDatabase ?? "none"
        )
    }

    private var diagram: some View {
        GeometryReader { proxy in
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(V2ERDottedBackground())
                .contentShape(Rectangle())
                .clipped()
                .gesture(dragGesture.simultaneously(with: magnifyGesture))
                .onContinuousHover { updateHover($0) }
                .onTapGesture { state.selectedTable = state.tableAt(viewPoint: $0) }
                .overlay(alignment: .bottomTrailing) { V2ERCanvasToolbar(state: state) }
                .onAppear {
                    state.viewportSize = proxy.size
                    fitIfNeeded(size: proxy.size)
                }
                .onChange(of: proxy.size) { newSize in
                    state.viewportSize = newSize
                    fitIfNeeded(size: newSize)
                }
                .onChange(of: state.needsInitialFit) { _ in fitIfNeeded(size: proxy.size) }
        }
    }

    private var canvas: some View {
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

    private func fitIfNeeded(size: CGSize) {
        guard state.needsInitialFit, size.width > 0, !state.isEmpty, state.canvasSize.width > 0 else { return }
        state.fitToWindow()
        state.consumeInitialFit()
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if !state.isDragging {
                    state.beginDrag(at: value.startLocation)
                    if state.draggingTable != nil {
                        if hoverCursor != nil { NSCursor.pop() }
                        NSCursor.closedHand.push()
                        hoverCursor = .closedHand
                    }
                }
                state.updateDrag(translation: value.translation)
            }
            .onEnded { _ in
                state.endDrag()
                if hoverCursor == .closedHand {
                    NSCursor.pop()
                    hoverCursor = nil
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if magnifyStartMag == nil { magnifyStartMag = state.magnification }
                let base = magnifyStartMag ?? state.magnification
                state.zoom(to: base * value)
            }
            .onEnded { _ in magnifyStartMag = nil }
    }

    private func updateHover(_ phase: HoverPhase) {
        switch phase {
        case let .active(location):
            state.isMouseOverCanvas = true
            guard state.draggingTable == nil else { return }
            let desired: NSCursor? = state.tableAt(viewPoint: location) != nil ? .openHand : nil
            if desired !== hoverCursor {
                if hoverCursor != nil { NSCursor.pop() }
                desired?.push()
                hoverCursor = desired
            }
        case .ended:
            state.isMouseOverCanvas = false
            if hoverCursor != nil { NSCursor.pop(); hoverCursor = nil }
        }
    }

    private func attachScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard state.isMouseOverCanvas else { return event }
            if event.modifierFlags.contains(.command) {
                state.zoom(to: state.magnification + event.scrollingDeltaY * 0.01)
                return nil
            }
            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 10.0
            state.canvasOffset = CGPoint(
                x: state.canvasOffset.x + event.scrollingDeltaX * multiplier,
                y: state.canvasOffset.y + event.scrollingDeltaY * multiplier
            )
            return nil
        }
    }

    private func detachScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.connected.to.line.below")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(KTEditorTheme.label3)
            Text("No tables")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Text("Select a database with tables to see its ER diagram.")
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }
    private func centeredView(@ViewBuilder content: () -> some View) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }
}
