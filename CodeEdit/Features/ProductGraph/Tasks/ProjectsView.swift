//
//  ProjectsView.swift
//  CodeEdit
//

import SwiftUI

/// The Projects surface — a list of bodies of work with status, progress, and target date.
///
/// Backed by the local-first `ProjectStore`; progress is derived from the linked tasks in
/// `TaskStore`. Selecting a project jumps to Tasks (filtering comes in a later pass).
struct ProjectsView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var taskStore: TaskStore
    var onOpenTasks: () -> Void

    @State private var draft: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(projectStore.projects) { project in
                    ProjectRow(
                        project: project,
                        taskCount: taskStore.tasks(for: project.id).count,
                        progress: progress(for: project),
                        onOpen: onOpenTasks
                    )
                    Divider().padding(.leading, 20)
                }
                if projectStore.projects.isEmpty { emptyState }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.automatic)
        .safeAreaInset(edge: .top, spacing: 0) {
            StudioTopBar(verticalPadding: 16) {
                VStack(spacing: 12) {
                    StudioPageHeader(title: "Projects", subtitle: "\(projectStore.activeCount) active") {
                        EmptyView()
                    }
                    composer
                }
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func progress(for project: ProjectItem) -> Double {
        let items = taskStore.tasks(for: project.id)
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.status == .done }.count) / Double(items.count)
    }

    private var composer: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.textTertiary)
            TextField("Add a project…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(submit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                .fill(StudioTheme.hover)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                        .strokeBorder(StudioTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func submit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        draft = ""
        Task { _ = try? await projectStore.newProject(title: title) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(StudioTheme.textTertiary)
            Text("No projects yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
            Text("Group related tasks into a project to track progress toward a goal.")
                .font(.system(size: 12.5))
                .foregroundStyle(StudioTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

// MARK: - Project row

private struct ProjectRow: View {
    let project: ProjectItem
    let taskCount: Int
    let progress: Double
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Circle().fill(project.status.tint).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)
                    Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                Spacer(minLength: 12)
                Text(project.status.displayName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 86, alignment: .leading)
                StudioProgressBar(value: progress, width: 90)
                if let target = project.target, !target.isEmpty {
                    Text(target)
                        .font(.system(size: 11))
                        .foregroundStyle(StudioTheme.textTertiary)
                        .frame(width: 80, alignment: .trailing)
                } else {
                    Spacer().frame(width: 80)
                }
                if let lead = project.lead, !lead.isEmpty {
                    StudioAvatar(initials: lead)
                } else {
                    Spacer().frame(width: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(hovering ? StudioTheme.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering = $0 }
    }
}
