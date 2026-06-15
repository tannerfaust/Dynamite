//
//  StudioComponents.swift
//  CodeEdit
//
//  Small, shared building blocks for the Studio surfaces (Home, Tasks, Projects). Kept here so the
//  surfaces stay declarative and visually consistent.
//

import SwiftUI

// MARK: - Floating top bar

/// A translucent, blurred top bar that floats over a surface's scrolling content (macOS-native
/// `.regularMaterial`). Apply via `.safeAreaInset(edge: .top)` so content scrolls underneath the
/// blur. The bottom hairline appears only as a faint seam against the moving content below.
struct StudioTopBar<Content: View>: View {
    var horizontalPadding: CGFloat = 24
    var verticalPadding: CGFloat = 12
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? .regularMaterial : .thinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StudioTheme.hairline)
                    .frame(height: 1)
            }
    }
}

// MARK: - Section heading

/// Uppercase, quiet section label used above lists.
struct StudioSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(StudioTheme.textTertiary)
    }
}

// MARK: - Page header

/// Standard surface header: title + subtitle on the left, trailing actions on the right.
struct StudioPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

// MARK: - Pill button

/// Small bordered action used in headers ("New task", "New doc").
struct StudioPillButton: View {
    let title: String
    var systemImage: String = "plus"
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(StudioTheme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.chipRadius, style: .continuous)
                    .fill(hovering ? StudioTheme.accent.opacity(0.12) : StudioTheme.accent.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioTheme.chipRadius, style: .continuous)
                            .strokeBorder(StudioTheme.accent.opacity(hovering ? 0.35 : 0.18), lineWidth: 1)
                    )
            )
            .scaleEffect(hovering ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(title)
        .onHover { hover in withAnimation(StudioMotion.hover) { hovering = hover } }
    }
}

// MARK: - Tag

/// A quiet labeled tag (project name, label) tinted by `color`.
struct StudioTag: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - Avatar

/// Initials chip for an assignee/lead.
struct StudioAvatar: View {
    let initials: String
    var size: CGFloat = 20

    var body: some View {
        Circle()
            .fill(StudioTheme.accent.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(StudioTheme.accent)
            )
    }
}

// MARK: - Progress bar

struct StudioProgressBar: View {
    /// 0…1.
    let value: Double
    var width: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(StudioTheme.hover)
                Capsule()
                    .fill(StudioTheme.accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(width: width, height: 5)
    }
}

// MARK: - Metric card

struct StudioMetricCard: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCard()
    }
}

// MARK: - Task row

/// A single task row, used on Home ("Up next") and inside Tasks.
struct StudioTaskRow: View {
    let task: TaskItem
    var projectName: String?
    var onToggle: (() -> Void)?
    var onOpen: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            if task.priority != .none {
                Image(systemName: task.priority == .urgent ? "exclamationmark" : "line.3.horizontal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(task.priority.tint)
                    .frame(width: 14)
            } else {
                Spacer().frame(width: 14)
            }

            Button(action: { onToggle?() }) {
                Image(systemName: task.status.systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(task.status.tint)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel(task.status == .done ? "Mark task active" : "Mark task done")

            Text(task.displayTitle)
                .font(.system(size: 13))
                .foregroundStyle(task.status == .done ? StudioTheme.textTertiary : StudioTheme.textPrimary)
                .strikethrough(task.status == .done, color: StudioTheme.textTertiary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let projectName, !projectName.isEmpty {
                StudioTag(text: projectName, color: .accentColor)
            }
            if let due = task.due, !due.isEmpty {
                Text(due)
                    .font(.system(size: 11))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            if let assignee = task.assignee, !assignee.isEmpty {
                StudioAvatar(initials: assignee)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(hovering ? StudioTheme.hover : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(task.displayTitle)
        .onHover { hovering = $0 }
    }
}
