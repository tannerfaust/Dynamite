//
//  StudioSurface.swift
//  CodeEdit
//

import SwiftUI

/// Product Studio registered as a Cockpit surface (ADR-0006 §2).
///
/// Registered in `ShellViewController.viewDidLoad()` when `FeatureFlags.cockpitView`
/// is true. `StudioRootView` owns its own `StudioViewModel` (and the nested
/// `ArtifactStore`) via `@StateObject` — this wrapper only carries registration
/// metadata and the workspace URL.
struct StudioSurface: CockpitSurface {
    let id = "studio"
    let title = "Studio"
    let systemImage = "doc.richtext"
    let workspaceURL: URL
    weak var linkIndexManager: LinkIndexManager?

    var body: AnyView {
        AnyView(StudioRootView(workspaceURL: workspaceURL, linkIndexManager: linkIndexManager))
    }
}
