//
//  ProductStudioRootView.swift
//  CodeEdit
//
//  The Product Studio: Dynamite's product-ownership surface. A bespoke, native surface (Linear /
//  Obsidian in spirit) with a labeled sidebar, a real Home dashboard, first-class Tasks & Projects,
//  the typed-doc workspace, and the product map — plus one button into Ground Control.
//
//  Structural invariant (ARCHITECTURE.md / ADR-0006): the Studio never depends on the editor being
//  open or a repo being connected; it degrades gracefully with no project and no index.
//

import SwiftUI

struct ProductStudioRootView: View {
    // MARK: - Inputs

    private let workspaceURL: URL?
    private let router: Router?
    private let sourceControlManager: SourceControlManager?
    private let onOpenGroundControl: () -> Void

    /// Shared model for the typed-doc workspace + Home doc stats.
    @StateObject private var studio: StudioViewModel
    /// Local-first work-item stores (Linear sync later).
    @StateObject private var taskStore: TaskStore
    @StateObject private var projectStore: ProjectStore

    @State private var section: StudioSection = .home

    init(
        workspaceURL: URL?,
        linkIndexManager: LinkIndexManager?,
        router: Router?,
        sourceControlManager: SourceControlManager? = nil,
        onOpenGroundControl: @escaping () -> Void
    ) {
        self.workspaceURL = workspaceURL
        self.router = router
        self.sourceControlManager = sourceControlManager
        self.onOpenGroundControl = onOpenGroundControl
        let url = workspaceURL ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        _studio = StateObject(
            wrappedValue: StudioViewModel(workspaceURL: url, linkIndexManager: linkIndexManager)
        )
        _taskStore = StateObject(wrappedValue: TaskStore(workspaceURL: url))
        _projectStore = StateObject(wrappedValue: ProjectStore(workspaceURL: url))
    }

    private var projectName: String {
        workspaceURL?.lastPathComponent ?? "Untitled"
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            StudioSidebar(
                section: $section,
                projectName: projectName,
                sourceControlManager: sourceControlManager,
                onOpenGroundControl: onOpenGroundControl,
                onSearch: { goTo(.docs) }
            )
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(section)
                .transition(.opacity)
                .animation(StudioMotion.section, value: section)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StudioTheme.windowBackground)
        .onReceive(NotificationCenter.default.publisher(for: .cockpitFocusSurface)) { note in
            guard isForThisWorkspace(note), let id = note.userInfo?["id"] as? String,
                  let target = StudioSection.from(surfaceID: id) else { return }
            section = target
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitFocusNode)) { note in
            // Node focus lands in the doc workspace; StudioViewModel selects the artifact.
            guard isForThisWorkspace(note) else { return }
            section = .docs
        }
    }

    private func goTo(_ target: StudioSection) {
        section = target
    }

    // MARK: - Section content

    @ViewBuilder private var content: some View {
        switch section {
        case .home:
            StudioOverviewView(
                studio: studio,
                store: studio.store,
                taskStore: taskStore,
                projectStore: projectStore,
                projectName: projectName,
                onSelectSection: { goTo($0) }
            )
        case .tasks:
            TasksView(taskStore: taskStore, projectStore: projectStore)
        case .projects:
            ProjectsView(
                projectStore: projectStore,
                taskStore: taskStore,
                onOpenTasks: { goTo(.tasks) }
            )
        case .roadmap:
            sectionShell(.roadmap) { RoadmapBoardView(viewModel: studio) }
        case .docs:
            DocsListView(viewModel: studio)
        case .map:
            sectionShell(.map) {
                ProductMapView(linkIndexManager: studio.linkIndexManager, router: router)
            }
        }
    }

    /// Wraps an embedded surface beneath a floating, blurred top bar so every destination shares the
    /// Studio chrome and content scrolls under a native blur.
    private func sectionShell(
        _ section: StudioSection,
        @ViewBuilder _ inner: () -> some View
    ) -> some View {
        inner()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                StudioTopBar(verticalPadding: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(section.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)
                        Text(section.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(StudioTheme.textTertiary)
                        Spacer()
                    }
                }
            }
    }

    // MARK: - Helpers

    private func isForThisWorkspace(_ note: Notification) -> Bool {
        guard let origin = note.userInfo?["workspaceURL"] as? URL else { return true }
        guard let workspaceURL else { return false }
        return origin.standardizedFileURL.path == workspaceURL.standardizedFileURL.path
    }
}
