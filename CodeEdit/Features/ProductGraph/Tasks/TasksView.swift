//
//  TasksView.swift
//  CodeEdit
//

import SwiftUI

/// The Tasks surface — a Linear-style list grouped by status, with an inline composer.
///
/// List view only for now (board comes later). Backed by the local-first `TaskStore`; the same UI
/// will bind to Linear once a `LinearSyncing` adapter ships.
struct TasksView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore

    @State private var draft: String = ""

    /// Status groups in display order; empty groups are hidden.
    private let order: [TaskStatus] = [.inProgress, .todo, .backlog, .done, .canceled]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(order, id: \.self) { status in
                    let items = tasks(in: status)
                    if !items.isEmpty {
                        groupHeader(status, count: items.count)
                        ForEach(items) { task in
                            StudioTaskRow(
                                task: task,
                                projectName: projectStore.project(id: task.projectID)?.displayTitle,
                                onToggle: { taskStore.toggleDone(task) },
                                onOpen: nil
                            )
                            .padding(.horizontal, 10)
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                if taskStore.tasks.isEmpty { emptyState }
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
                    StudioPageHeader(title: "Tasks", subtitle: "\(taskStore.activeCount) active") {
                        EmptyView()
                    }
                    composer
                }
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func tasks(in status: TaskStatus) -> [TaskItem] {
        taskStore.tasks
            .filter { $0.status == status }
            .sorted { $0.priority.rank < $1.priority.rank }
    }

    private func groupHeader(_ status: TaskStatus, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: status.systemImage)
                .font(.system(size: 12))
                .foregroundStyle(status.tint)
            Text(status.displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
            Text("\(count)")
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var composer: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.textTertiary)
            TextField("Add a task…", text: $draft)
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
        Task { _ = try? await taskStore.newTask(title: title) }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(StudioTheme.textTertiary)
            Text("No tasks yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
            Text("Type above and press return to add your first task.")
                .font(.system(size: 12.5))
                .foregroundStyle(StudioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}
