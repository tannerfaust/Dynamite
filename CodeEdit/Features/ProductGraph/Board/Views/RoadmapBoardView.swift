//
//  RoadmapBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Now / Next / Later columns aggregating `roadmap-item` artifacts.
struct RoadmapBoardView: View {
    @ObservedObject var viewModel: StudioViewModel
    @State private var columns: [RoadmapColumn] = []

    private let horizons = ["now", "next", "later"]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach($columns) { $column in
                    roadmapColumn(column: $column)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: reloadColumns)
        .onChange(of: viewModel.store.artifacts) { _, _ in reloadColumns() }
    }

    private func roadmapColumn(column: Binding<RoadmapColumn>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(column.wrappedValue.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(column.wrappedValue.items) { item in
                    roadmapCard(item: item, horizon: column.wrappedValue.horizon)
                }
            }

            Button {
                viewModel.createArtifact(
                    kind: .roadmapItem,
                    title: "New \(column.wrappedValue.title) Item",
                    extraFields: ["horizon": column.wrappedValue.horizon]
                )
            } label: {
                Label("Add item", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(width: 260)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(horizonColor(column.wrappedValue.horizon).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(horizonColor(column.wrappedValue.horizon).opacity(0.15), lineWidth: 0.5)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first,
                  let artifact = viewModel.store.artifacts.first(where: { $0.id == id }) else { return false }
            moveArtifact(artifact, to: column.wrappedValue.horizon)
            return true
        }
    }

    private func roadmapCard(item: ProductArtifact, horizon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
            if !item.links.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(item.links) { link in
                        LinkChipView(link: link)
                    }
                }
            }
            StatusBadge(status: item.status)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .draggable(item.id)
        .onTapGesture { viewModel.selectedArtifactID = item.id }
    }

    private func reloadColumns() {
        let items = viewModel.store.artifacts.filter { $0.kind == .roadmapItem }
        columns = horizons.map { horizon in
            RoadmapColumn(
                horizon: horizon,
                items: items.filter { ($0.extraFields["horizon"] ?? "later") == horizon }
            )
        }
    }

    private func moveArtifact(_ artifact: ProductArtifact, to horizon: String) {
        var updated = artifact
        updated.extraFields["horizon"] = horizon
        viewModel.save(updated)
        reloadColumns()
    }

    private func horizonColor(_ horizon: String) -> Color {
        switch horizon {
        case "now":   return .green
        case "next":  return .orange
        default:      return .blue
        }
    }
}
