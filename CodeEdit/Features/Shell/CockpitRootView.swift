//
//  CockpitRootView.swift
//  CodeEdit
//

import SwiftUI

/// Top-level layout for the Cockpit view mode.
///
/// Phase 1 (T1.4): empty registered-surface container with a placeholder when no surfaces
/// are registered. Studio surfaces (T1.6+) register into `CockpitSurfaceRegistry` and appear
/// in the sidebar automatically once added.
///
/// The Cockpit is structurally independent from the IDE split view — it has its own
/// sidebar + content area layout that is NOT the 3-pane `NSSplitViewController`.
struct CockpitRootView: View {
    // MARK: - Properties

    /// Registry of surfaces registered by Studio features (T1.6+).
    @ObservedObject var registry: CockpitSurfaceRegistry

    /// Workspace folder URL; used to label the sidebar and to ignore focus
    /// notifications originating from other project windows.
    var workspaceURL: URL?

    /// ID of the currently selected surface, persisted via `WorkspaceStateKey`.
    @State private var selectedSurfaceID: String?

    private var projectName: String {
        workspaceURL?.lastPathComponent ?? "No Project"
    }

    /// True when a focus notification belongs to this window's workspace.
    private func isForThisWorkspace(_ note: Notification) -> Bool {
        guard let origin = note.userInfo?["workspaceURL"] as? URL else { return true }
        guard let workspaceURL else { return false }
        return origin.standardizedFileURL.path == workspaceURL.standardizedFileURL.path
    }

    // MARK: - Body

    var body: some View {
        if registry.surfaces.isEmpty {
            emptyPlaceholder
        } else {
            surfaceLayout
        }
    }

    // MARK: - Empty state

    private var emptyPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.tertiary)
            Text("Cockpit")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Studio surfaces appear here in Phase 1 (T1.6+).")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }

    // MARK: - Surface layout

    /// Sidebar + content area once surfaces are registered.
    ///
    /// Full implementation arrives with T1.6+ (typed-doc editor, product map, etc.).
    private var surfaceLayout: some View {
        NavigationSplitView {
            List(selection: $selectedSurfaceID) {
                Section(projectName) {
                    ForEach(registry.surfaces) { surface in
                        Label(surface.title, systemImage: surface.systemImage)
                            .tag(surface.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .listStyle(.sidebar)
        } detail: {
            if let id = selectedSurfaceID,
               let surface = registry.surfaces.first(where: { $0.id == id }) {
                surface.body
            } else {
                emptyPlaceholder
            }
        }
        .background(.windowBackground)
        .onAppear {
            if selectedSurfaceID == nil {
                selectedSurfaceID = registry.surfaces.first?.id
            }
        }
        .onChange(of: registry.surfaces) { _, newSurfaces in
            if selectedSurfaceID == nil || !newSurfaces.contains(where: { $0.id == selectedSurfaceID }) {
                selectedSurfaceID = newSurfaces.first?.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitFocusSurface)) { note in
            if isForThisWorkspace(note),
               let id = note.userInfo?["id"] as? String,
               registry.surfaces.contains(where: { $0.id == id }) {
                selectedSurfaceID = id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitFocusNode)) { note in
            // Node focus lands in Studio; StudioViewModel consumes the same notification
            // to select the artifact.
            if isForThisWorkspace(note),
               registry.surfaces.contains(where: { $0.id == "studio" }) {
                selectedSurfaceID = "studio"
            }
        }
    }
}
