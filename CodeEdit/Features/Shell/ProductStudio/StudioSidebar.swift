//
//  StudioSidebar.swift
//  CodeEdit
//

import SwiftUI

/// The Studio's left navigation — a *floating* Liquid Glass panel (macOS 26 in spirit, material
/// fallback below) that hovers over the canvas with an inset margin and a soft shadow. A workspace
/// switcher, a ⌘K search affordance, grouped destinations whose selection indicator glides on a
/// spring, and a pinned "Ground Control" capsule at the bottom. Native, system-appearance,
/// system-accent.
struct StudioSidebar: View {
    @Binding var section: StudioSection
    let projectName: String
    /// Optional git source control, surfaced as a compact branch chip under the workspace name. Nil
    /// when there's no repo — Product Studio never depends on one.
    var sourceControlManager: SourceControlManager?
    /// Invoked when the user jumps to Ground Control for code review and agent supervision.
    var onOpenGroundControl: () -> Void
    /// Invoked when the user activates the search affordance (⌘K).
    var onSearch: () -> Void

    /// Drives the gliding selection indicator shared across nav rows.
    @Namespace private var selectionGlass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceSwitcher
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(StudioNavGroup.allCases) { group in
                        if let title = group.title {
                            Text(title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(StudioTheme.textTertiary)
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                        }
                        ForEach(group.sections) { item in
                            NavRow(
                                section: item,
                                isSelected: item == section,
                                namespace: selectionGlass
                            ) {
                                withAnimation(StudioMotion.snappy) { section = item }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }
            .scrollIndicators(.never)

            groundControlRow
        }
        .frame(width: 228)
        .frame(maxHeight: .infinity, alignment: .top)
        .studioPanel(radius: StudioTheme.radiusPanel)
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 10)
    }

    // MARK: - Workspace switcher

    private var workspaceSwitcher: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(StudioTheme.accent)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: StudioTheme.accent.opacity(0.35), radius: 5, x: 0, y: 2)
            Text(projectName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(projectName)
    }

    // MARK: - Search

    private var searchField: some View {
        Button(action: onSearch) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(StudioTheme.textTertiary)
                Text("Search")
                    .font(.system(size: 12.5))
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer(minLength: 0)
                Text("⌘K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                    .fill(StudioTheme.hover)
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Search docs")
        .help("Search docs")
    }

    // MARK: - Ground Control row

    private var groundControlRow: some View {
        VStack(spacing: 8) {
            if let sourceControlManager {
                StudioBranchChip(sourceControlManager: sourceControlManager)
            }
            GroundControlButton(action: onOpenGroundControl)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Nav row

private struct NavRow: View {
    let section: StudioSection
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? StudioTheme.accent : StudioTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                        .fill(StudioTheme.selection)
                        .matchedGeometryEffect(id: "studioNavSelection", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                        .fill(StudioTheme.hover)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hover in
            withAnimation(StudioMotion.hover) { hovering = hover }
        }
    }
}

// MARK: - Branch chip

/// A quiet, product-friendly git branch row for the Studio sidebar footer — grouped with the Ground
/// Control gateway since branch is repo/code context, not project identity. Replaces the technical
/// IDE branch picker in the toolbar but still lets you switch branches via a menu. Renders nothing
/// when there's no repo, so the Studio never depends on source control.
private struct StudioBranchChip: View {
    @ObservedObject var sourceControlManager: SourceControlManager
    @State private var hovering = false

    var body: some View {
        // A ZStack (not a Group) so the refresh `.task` always runs — even before a branch is known.
        // A `Group` forwards modifiers to its children, so an empty Group would never run the task,
        // leaving the chip permanently hidden until something else populated the branch.
        ZStack(alignment: .leading) {
            if let current = sourceControlManager.currentBranch {
                Menu {
                    ForEach(sourceControlManager.orderedLocalBranches, id: \.self) { branch in
                        Button {
                            switchTo(branch)
                        } label: {
                            if branch == current {
                                Label(branch.name, systemImage: "checkmark")
                            } else {
                                Text(branch.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 18)
                        Text(current.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .opacity(hovering ? 0.7 : 0.35)
                    }
                    .foregroundStyle(StudioTheme.textTertiary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                            .fill(hovering ? StudioTheme.hover : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onHover { hovering = $0 }
                .help("Current branch — click to switch")
            }
        }
        .task {
            guard Settings.shared.preferences.sourceControl.general.sourceControlIsEnabled else { return }
            await sourceControlManager.refreshCurrentBranch()
            await sourceControlManager.refreshBranches()
        }
    }

    private func switchTo(_ branch: GitBranch) {
        guard branch != sourceControlManager.currentBranch else { return }
        Task {
            do {
                try await sourceControlManager.checkoutBranch(branch: branch)
            } catch {
                await sourceControlManager.showAlertForError(title: "Failed to checkout", error: error)
            }
        }
    }
}

// MARK: - Ground Control button

/// The pinned gateway into Ground Control — a glass capsule that lifts on hover, signalling that it
/// crosses into the other environment.
private struct GroundControlButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                Text("Ground Control")
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                Text("⌘2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            .foregroundStyle(StudioTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                    .fill(hovering ? StudioTheme.pressed : StudioTheme.hover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusChip, style: .continuous)
                    .strokeBorder(StudioTheme.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Open Ground Control")
        .help("Open Ground Control")
        .onHover { hover in
            withAnimation(StudioMotion.hover) { hovering = hover }
        }
    }
}
