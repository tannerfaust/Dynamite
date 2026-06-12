// swiftlint:disable identifier_name
//
//  ProductMapView.swift
//  CodeEdit
//

import SwiftUI
import AppKit

/// Root view for the Product Map Cockpit surface.
///
/// Owns the `ProductMapViewModel` as a `@StateObject` so layout is computed once and survives
/// Cockpit navigation round-trips. The inner rendering is GPU-accelerated via SwiftUI `Canvas`.
struct ProductMapView: View {
    // Owns the view model so it persists across CockpitRootView re-renders
    @StateObject private var viewModel: ProductMapViewModel

    // Viewport state — independent from the model
    @State private var baseScale: CGFloat = 1.0
    @State private var scale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var panAnchor: CGSize = .zero

    init(linkIndexManager: LinkIndexManager?, router: Router? = nil) {
        _viewModel = StateObject(
            wrappedValue: ProductMapViewModel(linkIndexManager: linkIndexManager, router: router)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            mapArea
        }
        .task { await viewModel.load() }
        .toolbar { mapToolbar }
        .background(.windowBackground)
    }

    // MARK: - Filter bar

    @ViewBuilder private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                kindChips
                if !viewModel.allStatuses.isEmpty {
                    Divider().frame(height: 16)
                    statusChips
                }
                if !viewModel.kindFilter.isEmpty || !viewModel.statusFilter.isEmpty {
                    Button("Clear", action: viewModel.clearFilters)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 36)
    }

    @ViewBuilder private var kindChips: some View {
        if !viewModel.allKinds.isEmpty {
            Text("Kind").font(.caption).foregroundStyle(.secondary)
            ForEach(viewModel.allKinds, id: \.self) { kind in
                filterChip(
                    kind,
                    color: Color(nsColor: ArtifactKind.from(kind)?.categoryColor ?? .systemGray),
                    isSelected: viewModel.kindFilter.contains(kind)
                ) { viewModel.toggleKindFilter(kind) }
            }
        }
    }

    @ViewBuilder private var statusChips: some View {
        Text("Status").font(.caption).foregroundStyle(.secondary)
        ForEach(viewModel.allStatuses, id: \.self) { status in
            filterChip(status, color: .accentColor, isSelected: viewModel.statusFilter.contains(status)) {
                viewModel.toggleStatusFilter(status)
            }
        }
    }

    private func filterChip(
        _ label: String, color: Color, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? color : Color(nsColor: .quaternaryLabelColor), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Map area

    @ViewBuilder private var mapArea: some View {
        if !viewModel.isLayoutReady {
            ProgressView("Building map…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.nodes.isEmpty {
            emptyState
        } else {
            mapCanvas
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("No artifacts in index")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Text("Create artifacts in Studio — they appear once indexed.")
                .foregroundStyle(.tertiary)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapCanvas: some View {
        GeometryReader { geo in
            Canvas { context, size in
                drawGraph(&context, size: size)
            }
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .onTapGesture { location in
                handleTap(at: location, containerSize: geo.size)
            }
        }
    }

    // MARK: - Draw

    private func drawGraph(_ context: inout GraphicsContext, size: CGSize) {
        let displayNodes = viewModel.filteredNodes
        let displayEdges = viewModel.filteredEdges
        let nodeByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
        context.translateBy(x: size.width / 2 + panOffset.width, y: size.height / 2 + panOffset.height)
        context.scaleBy(x: scale, y: scale)
        drawEdges(&context, edges: displayEdges, nodeByID: nodeByID)
        drawNodes(&context, nodes: displayNodes)
        if scale > 0.55 { drawLabels(&context, nodes: displayNodes) }
    }

    private func drawEdges(
        _ context: inout GraphicsContext,
        edges: [ProductMapViewModel.MapEdge],
        nodeByID: [String: ProductMapViewModel.MapNode]
    ) {
        let lineWidth = max(0.5, 1.0 / scale)
        for edge in edges {
            guard let src = nodeByID[edge.srcID], let dst = nodeByID[edge.dstID] else { continue }
            var edgePath = Path()
            edgePath.move(to: src.position)
            edgePath.addLine(to: dst.position)
            let lineColor: Color = edge.resolved ? .secondary.opacity(0.3) : .orange.opacity(0.5)
            context.stroke(edgePath, with: .color(lineColor), lineWidth: lineWidth)
        }
    }

    private func drawNodes(_ context: inout GraphicsContext, nodes: [ProductMapViewModel.MapNode]) {
        let nodeRadius: CGFloat = 10.0
        for node in nodes {
            let rect = CGRect(
                x: node.position.x - nodeRadius, y: node.position.y - nodeRadius,
                width: nodeRadius * 2, height: nodeRadius * 2
            )
            let color = Color(nsColor: ArtifactKind.from(node.kindString)?.categoryColor ?? .systemGray)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            if node.id == viewModel.selectedNodeID {
                let ringRect = rect.insetBy(dx: -3.5, dy: -3.5)
                context.stroke(Path(ellipseIn: ringRect), with: .color(.white), lineWidth: 2.5 / scale)
            }
        }
    }

    private func drawLabels(_ context: inout GraphicsContext, nodes: [ProductMapViewModel.MapNode]) {
        let labelOffset: CGFloat = 13.0
        let fontSize = max(7.0, 9.0 / scale)
        for node in nodes {
            let labelPos = CGPoint(x: node.position.x, y: node.position.y + labelOffset)
            let resolved = context.resolve(
                Text(String(node.title.prefix(20)))
                    .font(.system(size: fontSize))
                    .foregroundColor(.primary)
            )
            context.draw(resolved, at: labelPos, anchor: .top)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                panOffset = CGSize(
                    width: panAnchor.width + value.translation.width,
                    height: panAnchor.height + value.translation.height
                )
            }
            .onEnded { _ in panAnchor = panOffset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { delta in scale = max(0.12, min(8.0, baseScale * delta)) }
            .onEnded { _ in baseScale = scale }
    }

    // MARK: - Hit testing

    private func handleTap(at location: CGPoint, containerSize: CGSize) {
        let graphX = (location.x - containerSize.width / 2 - panOffset.width) / scale
        let graphY = (location.y - containerSize.height / 2 - panOffset.height) / scale
        let graphPoint = CGPoint(x: graphX, y: graphY)
        let hitRadiusSq: CGFloat = 18.0 * 18.0

        var bestID: String?
        var bestDistSq = CGFloat.greatestFiniteMagnitude
        for node in viewModel.filteredNodes {
            let dx = node.position.x - graphPoint.x
            let dy = node.position.y - graphPoint.y
            let distSq = dx * dx + dy * dy
            if distSq < bestDistSq { bestDistSq = distSq; bestID = node.id }
        }
        guard let tapped = bestID, bestDistSq <= hitRadiusSq else {
            viewModel.selectedNodeID = nil; return
        }
        viewModel.openNode(id: tapped)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var mapToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                scale = 1.0; baseScale = 1.0; panOffset = .zero; panAnchor = .zero
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Reset viewport")
            Button { Task { await viewModel.reload() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Rebuild index and reload map")
        }
    }
}
