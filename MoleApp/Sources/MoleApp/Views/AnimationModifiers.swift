import SwiftUI

// MARK: - Glass Hover Effect (blur + glow on hover)

struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.018 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.6 : 0)
            )
            .shadow(
                color: MoleColors.accent.opacity(isHovered ? 0.08 : 0),
                radius: isHovered ? 12 : 0,
                y: isHovered ? 4 : 0
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MoleColors.accent.opacity(isHovered ? 0.15 : 0), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Staggered Appear (fade + slide up)

struct AppearAnimation: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - Pulse (breathing effect for loading states)

struct PulseEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.08
                }
            }
    }
}

// MARK: - Glow effect for important elements

struct GlowEffect: ViewModifier {
    let color: Color
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(glowing ? 0.4 : 0.1), radius: glowing ? 12 : 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
    }
}

// MARK: - Extensions

extension View {
    func hoverEffect() -> some View {
        modifier(HoverEffect())
    }

    func appearAnimation(delay: Double = 0) -> some View {
        modifier(AppearAnimation(delay: delay))
    }

    func pulseEffect() -> some View {
        modifier(PulseEffect())
    }

    func glowEffect(color: Color = MoleColors.accent) -> some View {
        modifier(GlowEffect(color: color))
    }
}
