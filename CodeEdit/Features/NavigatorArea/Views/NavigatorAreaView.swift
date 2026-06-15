//
//  NavigatorAreaView.swift
//  CodeEdit
//
//  Created by Lukas Pistrol on 17.03.22.
//

import SwiftUI

struct NavigatorAreaView: View {
    @ObservedObject private var workspace: WorkspaceDocument
    @ObservedObject private var extensionManager = ExtensionManager.shared
    @ObservedObject public var viewModel: NavigatorAreaViewModel
    private let onOpenProductStudio: () -> Void

    @AppSettings(\.general.navigatorTabBarPosition)
    var sidebarPosition: SettingsData.SidebarTabBarPosition

    init(
        workspace: WorkspaceDocument,
        viewModel: NavigatorAreaViewModel,
        onOpenProductStudio: @escaping () -> Void = {}
    ) {
        self.workspace = workspace
        self.viewModel = viewModel
        self.onOpenProductStudio = onOpenProductStudio

        viewModel.tabItems = [.project, .sourceControl, .search] +
            extensionManager
                .extensions
                .map { ext in
                    ext.availableFeatures.compactMap {
                        if case .sidebarItem(let data) = $0, data.kind == .navigator {
                            return NavigatorTab.uiExtension(endpoint: ext.endpoint, data: data)
                        }
                        return nil
                    }
                }
                .joined()
    }

    var body: some View {
        VStack(spacing: 0) {
            if FeatureFlags.cockpitView {
                ProductStudioShortcut {
                    onOpenProductStudio()
                }
                Divider()
            }

            WorkspacePanelView(
                viewModel: viewModel,
                selectedTab: $viewModel.selectedTab,
                tabItems: $viewModel.tabItems,
                sidebarPosition: sidebarPosition
            )
        }
        .environmentObject(workspace)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("navigator")
    }
}

private struct ProductStudioShortcut: View {
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                Text("Product Studio")
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("⌘1")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(hovering ? Color(nsColor: .controlAccentColor).opacity(0.10) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open Product Studio")
        .onHover { hovering = $0 }
        .help("Open Product Studio")
    }
}
