//
//  StudioOverviewView.swift
//  CodeEdit
//

import SwiftUI

/// The Product Studio home dashboard.
///
/// A quiet, native overview: greeting, live metrics, up-next tasks, active projects, and recent
/// docs. Observes the task/project/artifact stores directly so it stays current as files load.
struct StudioOverviewView: View {
    @ObservedObject var studio: StudioViewModel
    @ObservedObject var store: ArtifactStore
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore
    let projectName: String
    var onSelectSection: (StudioSection) -> Void

    private var artifacts: [ProductArtifact] { store.artifacts }

    var body: some View {
        StudioLargeTitleScreen(title: "Home") {
            HStack(spacing: 8) {
                StudioPillButton(title: "Task") { newTask() }
                StudioPillButton(title: "Doc") { newDoc() }
            }
        } content: {
            metrics
            upNext
            activeProjects
            recentDocs
        }
    }

    // MARK: - Metrics

    private var metrics: some View {
        HStack(spacing: 10) {
            StudioMetricCard(value: taskStore.activeCount, label: "Active tasks", systemImage: "checkmark.circle")
            StudioMetricCard(value: taskStore.inProgressCount, label: "In progress", systemImage: "circle.lefthalf.filled")
            StudioMetricCard(value: artifacts.count, label: "Artifacts", systemImage: "doc.text")
            StudioMetricCard(value: openQuestions, label: "Open questions", systemImage: "questionmark.circle")
        }
    }

    /// Untested/validating assumptions — the things still in question.
    private var openQuestions: Int {
        artifacts.filter { $0.kind == .assumption && ($0.status == "untested" || $0.status == "validating") }.count
    }

    // MARK: - Up next

    @ViewBuilder private var upNext: some View {
        let items = upNextTasks
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StudioSectionLabel(text: "Up next")
                Spacer()
                if !items.isEmpty {
                    Button("All tasks") { onSelectSection(.tasks) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.accent)
                        .focusEffectDisabled()
                }
            }
            if items.isEmpty {
                emptyTile(icon: "checkmark.circle", title: "No active tasks",
                          message: "Add a task to start tracking work.", action: "New task") { newTask() }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                        if index > 0 { Divider() }
                        StudioTaskRow(
                            task: task,
                            projectName: projectStore.project(id: task.projectID)?.displayTitle,
                            onToggle: { taskStore.toggleDone(task) },
                            onOpen: { onSelectSection(.tasks) }
                        )
                    }
                }
                .studioCard()
            }
        }
    }

    private var upNextTasks: [TaskItem] {
        taskStore.tasks
            .filter { $0.status.isActive }
            .sorted { lhs, rhs in
                if lhs.status.sortRank != rhs.status.sortRank { return lhs.status.sortRank < rhs.status.sortRank }
                return lhs.priority.rank < rhs.priority.rank
            }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Active projects

    @ViewBuilder private var activeProjects: some View {
        let items = projectStore.projects.filter { $0.status.isActive }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StudioSectionLabel(text: "Active projects")
                    Spacer()
                    Button("All projects") { onSelectSection(.projects) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.accent)
                        .focusEffectDisabled()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(items) { project in
                        ProjectMiniCard(
                            project: project,
                            progress: progress(for: project),
                            taskCount: taskStore.tasks(for: project.id).count,
                            onOpen: { onSelectSection(.projects) }
                        )
                    }
                }
            }
        }
    }

    private func progress(for project: ProjectItem) -> Double {
        let items = taskStore.tasks(for: project.id)
        guard !items.isEmpty else { return 0 }
        let done = items.filter { $0.status == .done }.count
        return Double(done) / Double(items.count)
    }

    // MARK: - Recent docs

    @ViewBuilder private var recentDocs: some View {
        let items = Array(artifacts.sorted { $0.updated > $1.updated }.prefix(5))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StudioSectionLabel(text: "Recent docs")
                Spacer()
                if !items.isEmpty {
                    Button("All docs") { onSelectSection(.docs) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.accent)
                        .focusEffectDisabled()
                }
            }
            if items.isEmpty {
                emptyTile(icon: "doc.text", title: "No docs yet",
                          message: "Capture a problem, persona, or interview.", action: "New doc") { newDoc() }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, artifact in
                        if index > 0 { Divider() }
                        DocRow(artifact: artifact) { open(artifact) }
                    }
                }
                .studioCard()
            }
        }
    }

    // MARK: - Actions

    private func newTask() {
        Task { _ = try? await taskStore.newTask(title: "New task") ; onSelectSection(.tasks) }
    }

    private func newDoc() {
        studio.showingNewArtifactSheet = true
        onSelectSection(.docs)
    }

    private func open(_ artifact: ProductArtifact) {
        studio.selectedArtifactID = artifact.id
        studio.displayMode = .artifacts
        onSelectSection(.docs)
    }

    private func emptyTile(icon: String, title: String, message: String,
                           action: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(StudioTheme.textTertiary)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(StudioTheme.textPrimary)
            Text(message).font(.system(size: 12)).foregroundStyle(StudioTheme.textSecondary)
            Button(action, action: perform)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .studioCard()
    }
}

// MARK: - Project mini card

private struct ProjectMiniCard: View {
    let project: ProjectItem
    let progress: Double
    let taskCount: Int
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(project.status.tint).frame(width: 8, height: 8)
                    Text(project.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text("\(taskCount) task\(taskCount == 1 ? "" : "s")\(project.target.map { " · target \($0)" } ?? "")")
                    .font(.system(size: 11))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                StudioProgressBar(value: progress).padding(.top, 2)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .studioCard(emphasized: hovering)
            .offset(y: hovering ? -2 : 0)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open project \(project.displayTitle)")
        .onHover { hover in withAnimation(StudioMotion.hover) { hovering = hover } }
    }
}

// MARK: - Doc row

private struct DocRow: View {
    let artifact: ProductArtifact
    let onOpen: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                Image(systemName: artifact.kind?.systemImage ?? "doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 18)
                Text(artifact.displayTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .opacity(hovering ? 1 : 0.35)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(hovering ? StudioTheme.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open doc \(artifact.displayTitle)")
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        let kind = artifact.kind?.displayName ?? artifact.kindString
        return artifact.updated.isEmpty ? kind : "\(kind) · \(artifact.updated)"
    }
}
