//
//  StoryMapBoardView.swift
//  CodeEdit
//

import SwiftUI

/// Lane board: H2 activities as columns, H3 steps as horizontal lanes, list items as cards.
struct StoryMapBoardView: View {
    @Binding var document: CanvasDocument
    var onCommit: () -> Void
    var onNavigateLink: ((ProductArtifact.ArtifactLink) -> Void)?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach($document.sections) { $activity in
                    activityRow(activity: $activity)
                }
                addActivityButton
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // swiftlint:disable:next function_body_length
    private func activityRow(activity: Binding<CanvasSection>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "Activity",
                text: Binding(
                    get: { activity.wrappedValue.heading },
                    set: { activity.wrappedValue.heading = $0 }
                )
            )
            .font(.system(size: 13, weight: .semibold))
            .textFieldStyle(.plain)
            .onSubmit(onCommit)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(activity.wrappedValue.subsections.indices, id: \.self) { laneIndex in
                        let lane = activity.wrappedValue.subsections[laneIndex]
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(
                                "Step",
                                text: Binding(
                                    get: { activity.wrappedValue.subsections[laneIndex].heading },
                                    set: { activity.wrappedValue.subsections[laneIndex].heading = $0 }
                                )
                            )
                            .font(.caption.weight(.semibold))
                            .textFieldStyle(.plain)
                            .onSubmit(onCommit)
                            BoardBlockView(
                                title: "",
                                guidance: lane.guidance,
                                cards: Binding(
                                    get: { activity.wrappedValue.subsections[laneIndex].cards },
                                    set: { activity.wrappedValue.subsections[laneIndex].cards = $0 }
                                ),
                                accent: .teal,
                                onCommit: onCommit,
                                onNavigateLink: onNavigateLink
                            )
                        }
                        .frame(width: 220)
                    }

                    Button {
                        activity.wrappedValue.subsections.append(CanvasSubsection(heading: "New Step"))
                        onCommit()
                    } label: {
                        Label("Add step", systemImage: "plus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, height: 120)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.teal.opacity(0.04))
        )
    }

    private var addActivityButton: some View {
        Button {
            document.sections.append(CanvasSection(heading: "New Activity"))
            onCommit()
        } label: {
            Label("Add activity", systemImage: "plus.circle")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
