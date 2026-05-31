//
//  GlassStyle.swift
//  CodeEdit
//
//  Created by Antigravity on 31/05/2026.
//

import SwiftUI

struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isEmphasized: Bool
    
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                EffectView(
                    colorScheme == .dark ? .hudWindow : .titlebar,
                    blendingMode: .withinWindow,
                    emphasized: isEmphasized
                )
            )
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1),
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    @State private var isHovering: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                EffectView(
                    .selection,
                    blendingMode: .withinWindow,
                    emphasized: configuration.isPressed
                )
                .opacity(isHovering ? 1.0 : 0.6)
            )
            .cornerRadius(10)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    /// Applies a hardware-accelerated glassmorphic panel style with a reflective liquid border and soft shadow.
    func glassPanel(cornerRadius: CGFloat = 12, isEmphasized: Bool = false) -> some View {
        self.modifier(GlassPanelModifier(cornerRadius: cornerRadius, isEmphasized: isEmphasized))
    }
}
