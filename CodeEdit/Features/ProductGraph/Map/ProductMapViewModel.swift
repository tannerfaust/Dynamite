//
//  ProductMapViewModel.swift
//  CodeEdit
//

import Foundation
import SwiftUI
import GRDB

/// View model for the Product Map surface.
///
/// Loads nodes and edges from `LinkIndexManager`, computes a force-directed layout
/// once on first load, and exposes filter state for kind/status/link-rel filtering.
/// Layout computation runs on a detached task so it never blocks the main thread.
@MainActor
final class ProductMapViewModel: ObservableObject {

    // MARK: - Nested types

    struct MapNode: Identifiable, Hashable {
        let id: String
        let kindString: String
        let status: String
        let title: String
        var position: CGPoint

        static func == (lhs: MapNode, rhs: MapNode) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    struct MapEdge: Identifiable, Hashable {
        var id: String { "\(srcID)-\(dstID)-\(rel)" }
        let srcID: String
        let dstID: String
        let rel: String
        let resolved: Bool
    }

    // MARK: - Published state

    @Published private(set) var nodes: [MapNode] = []
    @Published private(set) var edges: [MapEdge] = []
    @Published private(set) var isLayoutReady = false
    @Published var selectedNodeID: String?
    @Published var kindFilter: Set<String> = []
    @Published var statusFilter: Set<String> = []
    @Published var relFilter: Set<String> = []

    // MARK: - Derived

    var filteredNodes: [MapNode] {
        nodes.filter { node in
            (kindFilter.isEmpty || kindFilter.contains(node.kindString)) &&
            (statusFilter.isEmpty || statusFilter.contains(node.status))
        }
    }

    var filteredEdges: [MapEdge] {
        let nodeIDs = Set(filteredNodes.map(\.id))
        return edges.filter { edge in
            nodeIDs.contains(edge.srcID) && nodeIDs.contains(edge.dstID) &&
            (relFilter.isEmpty || relFilter.contains(edge.rel))
        }
    }

    var allKinds: [String] { Array(Set(nodes.map(\.kindString))).sorted() }
    var allStatuses: [String] { Array(Set(nodes.map(\.status))).sorted() }
    var allRels: [String] { Array(Set(edges.map(\.rel))).sorted() }

    // MARK: - Private

    private weak var linkIndexManager: LinkIndexManager?
    private weak var router: Router?

    // MARK: - Init

    init(linkIndexManager: LinkIndexManager?, router: Router? = nil) {
        self.linkIndexManager = linkIndexManager
        self.router = router
    }

    // MARK: - Navigation

    /// Selects the node and dispatches a `dynamite://node/<id>` route via the Shell router.
    ///
    /// The router is optional so the map remains functional (selection still works)
    /// with no workspace document — the standalone-mode invariant (ARCHITECTURE.md).
    func openNode(id: String) {
        selectedNodeID = id
        router?.handle(route: .node(id: id))
    }

    // MARK: - Load

    func load() async {
        guard let manager = linkIndexManager else { isLayoutReady = true; return }
        let (rawNodes, rawEdges) = await fetchGraph(from: manager)
        guard !rawNodes.isEmpty else { isLayoutReady = true; return }
        let laidOut = await Task.detached(priority: .userInitiated) {
            ProductMapViewModel.springLayout(nodes: rawNodes, edges: rawEdges)
        }.value
        nodes = laidOut
        edges = rawEdges
        isLayoutReady = true
    }

    func reload() async {
        isLayoutReady = false
        await load()
    }

    func toggleKindFilter(_ kind: String) {
        if kindFilter.contains(kind) { kindFilter.remove(kind) } else { kindFilter.insert(kind) }
    }

    func toggleStatusFilter(_ status: String) {
        if statusFilter.contains(status) { statusFilter.remove(status) } else { statusFilter.insert(status) }
    }

    func toggleRelFilter(_ rel: String) {
        if relFilter.contains(rel) { relFilter.remove(rel) } else { relFilter.insert(rel) }
    }

    func clearFilters() { kindFilter = []; statusFilter = []; relFilter = [] }

    // MARK: - DB fetch

    private func fetchGraph(from manager: LinkIndexManager) async -> ([MapNode], [MapEdge]) {
        guard let result = try? await manager.database.dbWriter.read({ db -> ([MapNode], [MapEdge]) in
            let rawNodes = try LinkIndexNode.fetchAll(db)
            let rawEdges = try LinkIndexEdge.fetchAll(db).filter(\.resolved)
            let mapNodes = rawNodes.map { node in
                MapNode(
                    id: node.id, kindString: node.kind, status: node.status,
                    title: node.title ?? node.id, position: .zero
                )
            }
            let mapEdges = rawEdges.map { edge in
                MapEdge(srcID: edge.srcId, dstID: edge.dstId, rel: edge.rel, resolved: edge.resolved)
            }
            return (mapNodes, mapEdges)
        }) else { return ([], []) }
        return result
    }

    // MARK: - Layout (runs off main thread)

    nonisolated static func springLayout(nodes: [MapNode], edges: [MapEdge]) -> [MapNode] {
        guard !nodes.isEmpty else { return nodes }
        let nodeCount = nodes.count
        let canvasSize = max(CGFloat(nodeCount) * 8.0, 800.0)
        var idToIndex = [String: Int](minimumCapacity: nodeCount)
        for (idx, node) in nodes.enumerated() { idToIndex[node.id] = idx }
        var positions = gridPositions(count: nodeCount, canvasSize: canvasSize)
        let edgePairs = resolveEdgePairs(edges: edges, idToIndex: idToIndex)
        positions = runFRIterations(positions: positions, edgePairs: edgePairs,
                                    nodeCount: nodeCount, canvasSize: canvasSize)
        var result = nodes
        for idx in 0..<nodeCount { result[idx].position = positions[idx] }
        return result
    }

    nonisolated private static func gridPositions(count: Int, canvasSize: CGFloat) -> [CGPoint] {
        let cols = Int(ceil(sqrt(Double(count))))
        let spacing = canvasSize / CGFloat(max(cols, 1))
        let halfCanvas = canvasSize / 2
        return (0..<count).map { idx in
            let col = idx % cols
            let row = idx / cols
            return CGPoint(
                x: CGFloat(col) * spacing + spacing / 2 - halfCanvas,
                y: CGFloat(row) * spacing + spacing / 2 - halfCanvas
            )
        }
    }

    nonisolated private static func resolveEdgePairs(edges: [MapEdge], idToIndex: [String: Int]) -> [(Int, Int)] {
        edges.compactMap { edge in
            guard let srcIdx = idToIndex[edge.srcID], let dstIdx = idToIndex[edge.dstID] else { return nil }
            return (srcIdx, dstIdx)
        }
    }

    nonisolated private static func runFRIterations(
        positions: [CGPoint], edgePairs: [(Int, Int)], nodeCount: Int, canvasSize: CGFloat
    ) -> [CGPoint] {
        let kRepulsion: CGFloat = 900.0
        let kAttraction: CGFloat = 0.03
        var temperature: CGFloat = canvasSize * 0.12
        let cooling: CGFloat = 0.90
        let iterations = min(100, 15 + nodeCount / 4)
        var pos = positions
        for _ in 0..<iterations {
            var forces = [CGPoint](repeating: .zero, count: nodeCount)
            applyRepulsion(positions: pos, forces: &forces, kRepulsion: kRepulsion, nodeCount: nodeCount)
            applyAttraction(edgePairs: edgePairs, positions: pos, forces: &forces, kAttraction: kAttraction)
            clampAndApply(positions: &pos, forces: forces, temperature: temperature,
                          canvasSize: canvasSize, nodeCount: nodeCount)
            temperature *= cooling
        }
        return pos
    }

    nonisolated private static func applyRepulsion(
        positions: [CGPoint], forces: inout [CGPoint], kRepulsion: CGFloat, nodeCount: Int
    ) {
        for idx in 0..<nodeCount {
            for jdx in (idx + 1)..<nodeCount {
                let dx = positions[idx].x - positions[jdx].x
                let dy = positions[idx].y - positions[jdx].y
                let distSq = max(dx * dx + dy * dy, 0.01)
                let dist = sqrt(distSq)
                let force = kRepulsion / distSq
                let fx = dx / dist * force; let fy = dy / dist * force
                forces[idx].x += fx; forces[idx].y += fy
                forces[jdx].x -= fx; forces[jdx].y -= fy
            }
        }
    }

    nonisolated private static func applyAttraction(
        edgePairs: [(Int, Int)], positions: [CGPoint], forces: inout [CGPoint], kAttraction: CGFloat
    ) {
        for (srcIdx, dstIdx) in edgePairs {
            let dx = positions[dstIdx].x - positions[srcIdx].x
            let dy = positions[dstIdx].y - positions[srcIdx].y
            let dist = max(sqrt(dx * dx + dy * dy), 0.1)
            let force = dist * kAttraction
            let fx = dx / dist * force; let fy = dy / dist * force
            forces[srcIdx].x += fx; forces[srcIdx].y += fy
            forces[dstIdx].x -= fx; forces[dstIdx].y -= fy
        }
    }

    nonisolated private static func clampAndApply(
        positions: inout [CGPoint], forces: [CGPoint],
        temperature: CGFloat, canvasSize: CGFloat, nodeCount: Int
    ) {
        let bound = canvasSize / 2 - 60
        for idx in 0..<nodeCount {
            let fx = forces[idx].x; let fy = forces[idx].y
            let fLen = max(sqrt(fx * fx + fy * fy), 0.001)
            let step = min(fLen, temperature)
            positions[idx].x = max(-bound, min(bound, positions[idx].x + fx / fLen * step))
            positions[idx].y = max(-bound, min(bound, positions[idx].y + fy / fLen * step))
        }
    }
}
