//
//  ViewModeSwitcherToolbarView.swift
//  CodeEdit
//

import SwiftUI

/// Segmented control embedded in the toolbar that switches between Cockpit (⌘1) and IDE (⌘2) modes.
///
/// Only rendered when `FeatureFlags.cockpitView` is true (Phase B+). The view observes
/// `CodeEditWindowController.viewMode` and writes back through `switchViewMode(to:)`.
struct ViewModeSwitcherToolbarView: View {
    @ObservedObject var windowController: CodeEditWindowController

    var body: some View {
        Picker("View Mode", selection: Binding(
            get: { windowController.viewMode },
            set: { windowController.switchViewMode(to: $0) }
        )) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Image(systemName: mode.systemImage)
                    .help(mode.displayName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 72)
    }
}
