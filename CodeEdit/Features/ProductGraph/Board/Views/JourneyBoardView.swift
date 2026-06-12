//
//  JourneyBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Column board for customer journey maps — one column per H2 stage.
struct JourneyBoardView: View {
    @Binding var document: CanvasDocument
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach($document.sections) { $section in
                    journeyColumn(section: $section)
                }
                addStageButton
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func journeyColumn(section: Binding<CanvasSection>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "Stage",
                text: Binding(
                    get: { section.wrappedValue.heading },
                    set: { section.wrappedValue.heading = $0 }
                )
            )
            .font(.system(size: 12, weight: .semibold))
            .textFieldStyle(.plain)
            .onSubmit(onCommit)

            BoardBlockView(
                title: "",
                guidance: section.wrappedValue.guidance,
                cards: section.cards,
                accent: .purple,
                onCommit: onCommit,
                onNavigateLink: onNavigateLink
            )
        }
        .frame(width: 240)
    }

    private var addStageButton: some View {
        Button {
            document.sections.append(CanvasSection(heading: "New Stage"))
            onCommit()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                Text("Add stage")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(width: 120, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }
}
