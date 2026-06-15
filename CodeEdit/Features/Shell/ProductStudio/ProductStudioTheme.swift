//
//  ProductStudioTheme.swift
//  CodeEdit
//
//  The Product Studio design language. The Studio is its own surface, but it stays *native*: it
//  follows the system appearance (light/dark) exactly like Ground Control and uses the user's system
//  accent — no hard-coded palettes, no gradients, no violet. The new direction layers macOS 26's
//  Liquid Glass onto Linear-grade restraint:
//
//    • Chrome floats. The sidebar and the top bars are translucent glass panels that hover over a
//      recessed canvas, with content scrolling underneath a native blur. (Real `glassEffect` on
//      macOS 26+, a `.regularMaterial` fallback below — see `studioGlass`.)
//    • Content stays calm. Cards are solid, hairline-bordered, softly shadowed, with concentric
//      corner radii — quiet objects, not glass everywhere.
//    • Motion is spring-based and quick. Selection glides; hovers lift; sections cross-fade.
//
//  Everything resolves through semantic system colors so the surface adapts with zero per-view
//  conditionals.
//

import SwiftUI

/// Semantic design tokens for the Product Studio surface.
enum StudioTheme {
    // MARK: - Accent (system)

    /// The user's system accent. Used only for selection and primary actions.
    static let accent = Color.accentColor

    // MARK: - Backgrounds

    /// The window canvas.
    ///
    /// Dark mode: `underPageBackgroundColor` — a recessed dark surface so glass chrome floats above it.
    /// Light mode: a near-white neutral (`#F5F5F6`) so the system grey doesn't dominate. White cards
    /// then float above the canvas via shadow — the same hierarchy Linear and modern macOS apps use.
    static var windowBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            guard appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua else {
                return NSColor(srgbRed: 0.961, green: 0.961, blue: 0.965, alpha: 1)
            }
            return .underPageBackgroundColor
        }))
    }

    /// Resting fill for cards and rows that sit on the canvas.
    ///
    /// White in light mode so cards visibly float above the near-white canvas via shadow.
    /// Dark: `controlBackgroundColor` (the standard dark-surface tone).
    static var cardFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            guard appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua else {
                return .white
            }
            return .controlBackgroundColor
        }))
    }

    /// Floating-panel fill (the sidebar). A *solid* adaptive surface, deliberately not a vibrancy
    /// material: AppKit desaturates materials to grey when the window isn't key (e.g. a background
    /// window tab), which made the sidebar flash grey. A solid fill stays crisp in every window state.
    /// Light: pure white floating on the `#F5F5F6` canvas. Dark: a slightly raised dark surface.
    static var panelFill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            guard appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua else {
                return .white
            }
            return NSColor(srgbRed: 0.149, green: 0.149, blue: 0.157, alpha: 1)
        }))
    }

    /// Subtle hover wash.
    static var hover: Color { Color.primary.opacity(0.055) }
    /// Pressed / active wash.
    static var pressed: Color { Color.primary.opacity(0.09) }
    /// Selection tint, accent-derived.
    static var selection: Color { accent.opacity(0.14) }

    // MARK: - Lines

    /// Hairline border / divider.
    static var hairline: Color { Color(nsColor: .separatorColor) }

    // MARK: - Text

    static var textPrimary: Color { .primary }
    static var textSecondary: Color { .secondary }
    static var textTertiary: Color { Color(nsColor: .tertiaryLabelColor) }

    // MARK: - Radii (concentric)

    static let radiusChip: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let radiusPanel: CGFloat = 18

    // Legacy aliases kept so existing call sites compile unchanged.
    static let cardRadius: CGFloat = 12
    static let chipRadius: CGFloat = 8

    // MARK: - Elevation

    /// Soft ambient shadow for floating objects.
    ///
    /// Light mode: 0.14 so white cards and the sidebar panel visibly float on the near-white canvas.
    /// Dark mode: 0.10 — shadow blends into the dark surface naturally.
    static var shadow: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor.black.withAlphaComponent(isDark ? 0.10 : 0.14)
        }))
    }
}

// MARK: - Motion

/// Shared animation curves so every surface moves with the same physics.
enum StudioMotion {
    /// Quick, slightly springy — selection indicators, taps, expansion.
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.82)
    /// Gentle settle — panel reveals, larger layout shifts.
    static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.90)
    /// Hover lifts and washes.
    static let hover = Animation.easeOut(duration: 0.14)
    /// Section cross-fades.
    static let section = Animation.easeOut(duration: 0.18)
}

// MARK: - Liquid Glass

/// Applies macOS 26 Liquid Glass to chrome, with a material fallback on macOS 14–15.
///
/// Light mode uses `.thinMaterial` — lighter, less grey than `.regularMaterial`, so the sidebar
/// reads as a crisp frosted white panel rather than a dull grey slab. Dark mode uses
/// `.regularMaterial` for proper dark-surface opacity.
private struct StudioGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            let material: Material = colorScheme == .dark ? .regularMaterial : .thinMaterial
            content
                .background(material, in: shape)
                .overlay(shape.strokeBorder(StudioTheme.hairline, lineWidth: 1))
        }
    }
}

// MARK: - Reusable styling

/// A quiet content card — a solid fill over a hairline, with a soft drop shadow and continuous
/// corners so it reads as a floating object rather than a boxed-in panel.
struct StudioCard: ViewModifier {
    var radius: CGFloat = StudioTheme.radiusCard
    var emphasized: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(StudioTheme.cardFill))
            .overlay(shape.fill(StudioTheme.hover).opacity(emphasized ? 1 : 0))
            .overlay(shape.strokeBorder(StudioTheme.hairline, lineWidth: 1))
            .shadow(color: StudioTheme.shadow, radius: emphasized ? 14 : 8,
                    x: 0, y: emphasized ? 5 : 3)
    }
}

extension View {
    /// Wraps the view in the Studio's quiet card treatment (solid fill, hairline, soft shadow).
    func studioCard(radius: CGFloat = StudioTheme.radiusCard, emphasized: Bool = false) -> some View {
        modifier(StudioCard(radius: radius, emphasized: emphasized))
    }

    /// Gives the view a floating Liquid Glass background clipped to `shape` (chrome only).
    func studioGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(StudioGlass(shape: shape))
    }

    /// A floating solid panel (the sidebar): solid `panelFill`, hairline, soft shadow, continuous
    /// corners. Unlike `studioGlass`, this never desaturates with window/tab state.
    func studioPanel(radius: CGFloat = StudioTheme.radiusPanel) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(StudioTheme.panelFill))
            .overlay(shape.strokeBorder(StudioTheme.hairline.opacity(0.7), lineWidth: 1))
            .shadow(color: StudioTheme.shadow, radius: 16, x: 0, y: 6)
    }

    /// Convenience: floating glass with a continuous rounded-rectangle of `radius`.
    func studioGlass(radius: CGFloat = StudioTheme.radiusPanel) -> some View {
        modifier(StudioGlass(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }
}
