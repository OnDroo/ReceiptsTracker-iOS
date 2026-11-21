import SwiftUI

// MARK: - Adaptive Liquid Glass Container (iOS 26+ with iOS 17-25 fallback)

struct AdaptiveGlassContainer<Content: View>: View {
    private let spacing: CGFloat?
    private let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Adaptive Liquid Glass View Modifiers

extension View {
    /// Native iOS content card surface with subtle elevation and hairline stroke.
    func nativeCardSurface(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }

    /// Applies authentic iOS 26 Liquid Glass on iOS 26+ and a clean frosted material pill on iOS 17–25.
    @ViewBuilder
    func adaptiveGlassCapsule(
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(interactive), in: Capsule())
            } else {
                self.glassEffect(.regular.interactive(interactive), in: Capsule())
            }
        } else {
            self
                .background {
                    if let tint {
                        Capsule()
                            .fill(tint.opacity(0.18))
                            .background(.ultraThinMaterial, in: Capsule())
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
        }
    }

    /// Applies iOS 26 Liquid Glass in a continuous rounded rectangle (for floating overlays and hero surfaces).
    @ViewBuilder
    func adaptiveGlassRect(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
            } else {
                self.glassEffect(.regular.interactive(interactive), in: shape)
            }
        } else {
            self
                .background {
                    if let tint {
                        shape
                            .fill(tint.opacity(0.14))
                            .background(.regularMaterial, in: shape)
                    } else {
                        shape
                            .fill(.regularMaterial)
                    }
                }
                .overlay(
                    shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }

    /// Applies `.buttonStyle(.glass)` on iOS 26+ and `.buttonStyle(.bordered)` on iOS 17–25.
    @ViewBuilder
    func adaptiveGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}
