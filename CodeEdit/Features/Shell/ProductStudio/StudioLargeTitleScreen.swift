//
//  StudioLargeTitleScreen.swift
//  CodeEdit
//
//  Native title scaffold for Product Studio surfaces.
//
//    • Real navigation chrome: a fixed title + trailing actions in a top bar (`safeAreaInset`).
//    • The top-of-scroll fade is the SYSTEM **scroll edge effect** (`ScrollEdgeEffectStyle`) — the OS
//      renders the soft, legibility-preserving fade where scrolling content meets the bar. It is NOT
//      a hand-built blur / `Material` / `glassEffect` slab.
//
//  Liquid Glass (`glassEffect`) is intentionally NOT used here — it is for floating controls (toolbar
//  buttons, chips), not for the top scroll fade.
//

import SwiftUI

/// A scrolling Studio surface with fixed navigation chrome and the system scroll edge effect on top.
struct StudioLargeTitleScreen<Actions: View, Content: View>: View {
    let title: String
    var maxContentWidth: CGFloat = 840
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    private let barHeight: CGFloat = 48

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                content()
            }
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 40)
            .padding(.top, 16)
            .padding(.bottom, 56)
        }
        .studioTopScrollEdgeEffect()
        .studioTopBar { topBar }
    }

    /// Real navigation chrome: the title + actions. No background of its own — the system scroll edge
    /// effect provides the soft fade that keeps this legible over the scrolling content beneath it.
    private var topBar: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)
            Spacer(minLength: 8)
            actions()
        }
        .frame(maxWidth: maxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 40)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    /// Applies the system scroll edge effect at the top edge (macOS 26+). The OS draws the soft,
    /// legibility-preserving fade where scrolling content meets the top bar — no hand-built blur.
    @ViewBuilder
    func studioTopScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// Pins the navigation chrome to the top. On macOS 26 it uses `safeAreaBar`, which marks the
    /// content as a *bar* so the scroll edge effect anchors to it (a plain `safeAreaInset` only
    /// reserves space and does not drive the effect). Falls back to `safeAreaInset` on older systems.
    @ViewBuilder
    func studioTopBar<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if #available(macOS 26.0, *) {
            self.safeAreaBar(edge: .top, spacing: 0, content: content)
        } else {
            self.safeAreaInset(edge: .top, spacing: 0, content: content)
        }
    }
}
