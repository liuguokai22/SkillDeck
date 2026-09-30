import SwiftUI

/// Shared Liquid Glass primitives for SkillDeck.
///
/// SkillDeck still supports macOS 14, while Apple's native Liquid Glass APIs start at macOS 26.
/// Keeping the availability check in one file lets feature views use one stable API:
/// - macOS 26 and newer render the real, system-provided Liquid Glass material.
/// - macOS 14 and 15 render a restrained material fallback with the same geometry.
///
/// This is intentionally a small design system rather than a replacement for standard SwiftUI
/// navigation. `NavigationSplitView`, toolbars, sheets, menus, and alerts already receive the
/// platform appearance automatically and should remain native controls.
enum LiquidGlass {

    /// Semantic window surfaces used by every destination in the three-column layout.
    ///
    /// AppKit semantic colors are used instead of fixed RGB values so the hierarchy remains
    /// readable in light mode, dark mode, increased contrast, and inactive windows. The sidebar
    /// is deliberately a little deeper than the two reading columns, while both content columns
    /// share the same paper-like system background.
    enum Surface {
        static var sidebar: Color { Color(nsColor: .windowBackgroundColor) }
        static var content: Color { Color(nsColor: .textBackgroundColor) }
    }

    /// Consistent radii make cards and compact controls feel related without turning every view
    /// into a capsule. `CGFloat` is Apple's platform-native floating-point type for layout values.
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 1_000
    }

    /// Shared control heights prevent visually adjacent glass surfaces from drifting by one or
    /// two points when their labels use different text styles or control implementations.
    enum Metrics {
        static let toolbarControlHeight: CGFloat = 30
        static let languageControlWidth: CGFloat = 94
        static let filterControlHeight: CGFloat = 28
        static let metadataBadgeHeight: CGFloat = 22
    }

    /// Describes the visual hierarchy of an action while allowing the modifier to choose the
    /// correct platform style for the current macOS version.
    enum ButtonProminence {
        case standard
        case prominent
    }

    /// A subtle edge used only by the pre-macOS 26 fallback. Native Liquid Glass draws its own
    /// highlights and must not be covered by a simulated glass border.
    static func fallbackSpecularBorder(opacity: Double = 0.24) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(opacity),
                Color.white.opacity(opacity * 0.35),
                Color.clear,
                Color.black.opacity(opacity * 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Search field

/// A toolbar-sized search field rendered as one interactive Liquid Glass surface.
///
/// SwiftUI's `.searchable` modifier decides its own toolbar chrome. That is normally desirable,
/// but it also prevents SkillDeck from matching the search field geometry to the neighboring
/// glass buttons. This small native `TextField` keeps standard keyboard editing and focus behavior
/// while letting the shared glass compatibility layer own the surrounding material.
struct LiquidGlassSearchField: View {

    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .frame(minWidth: 150, idealWidth: 230, maxWidth: 300)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 11)
        .liquidGlassToolbarControl()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Glass effect container

/// Groups nearby custom glass surfaces into one native rendering container on macOS 26+.
///
/// `GlassEffectContainer` improves rendering efficiency and lets the system coordinate the light
/// and geometry of sibling glass effects. The fallback returns the same content unchanged because
/// older material views do not need an effect container.
struct LiquidGlassGroup<Content: View>: View {

    let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Card container

/// A semantic content card backed by native Liquid Glass when the operating system supports it.
/// The glass itself is noninteractive; buttons inside the card remain the interactive elements.
struct LiquidGlassCard<Content: View>: View {

    var cornerRadius: CGFloat = LiquidGlass.CornerRadius.medium
    var padding: CGFloat = 16
    private let content: Content

    init(
        cornerRadius: CGFloat = LiquidGlass.CornerRadius.medium,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .modifier(
                LiquidGlassSurfaceModifier(
                    cornerRadius: cornerRadius,
                    tint: nil,
                    isInteractive: false,
                    fallbackElevation: 1
                )
            )
    }
}

// MARK: - Surface modifier

/// Applies a native or fallback glass surface without leaking availability checks into feature UI.
private struct LiquidGlassSurfaceModifier: ViewModifier {

    let cornerRadius: CGFloat
    let tint: Color?
    let isInteractive: Bool
    let fallbackElevation: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // `Glass` is a value type. Chaining `tint` and `interactive` creates a configured copy
            // in the same way that chained SwiftUI view modifiers create new view values.
            let baseGlass = Glass.regular.tint(tint)
            let configuredGlass = isInteractive ? baseGlass.interactive() : baseGlass

            content.glassEffect(
                configuredGlass,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            // `.ultraThinMaterial` is the closest system-managed fallback. It follows appearance,
            // vibrancy, and accessibility better than a hard-coded translucent color.
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            if let tint {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(tint)
                            }
                        }
                        .shadow(
                            color: Color.black.opacity(0.035 * Double(fallbackElevation)),
                            radius: 4 * fallbackElevation,
                            x: 0,
                            y: 2 * fallbackElevation
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LiquidGlass.fallbackSpecularBorder(),
                            lineWidth: 0.75
                        )
                )
        }
    }
}

// MARK: - Button style compatibility

/// Chooses Apple's Liquid Glass button styles on macOS 26+ and familiar bordered controls on
/// earlier releases. A `ViewModifier` is used because Swift's concrete button-style types differ
/// between the two availability branches.
private struct LiquidGlassButtonStyleModifier: ViewModifier {

    let prominence: LiquidGlass.ButtonProminence

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            switch prominence {
            case .standard:
                content.buttonStyle(.glass)
            case .prominent:
                content.buttonStyle(.glassProminent)
            }
        } else {
            switch prominence {
            case .standard:
                content.buttonStyle(.bordered)
            case .prominent:
                content.buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Exact toolbar geometry shared by buttons, menus, and the custom search field.
private struct LiquidGlassToolbarControlModifier: ViewModifier {

    let width: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let width {
            content
                .frame(width: width, height: LiquidGlass.Metrics.toolbarControlHeight)
                .contentShape(Capsule())
                .liquidGlassControl()
        } else {
            content
                .frame(height: LiquidGlass.Metrics.toolbarControlHeight)
                .contentShape(Capsule())
                .liquidGlassControl()
        }
    }
}

extension View {

    /// Gives toolbar controls one measured height while preserving a circular icon-only option.
    func liquidGlassToolbarControl(width: CGFloat? = nil) -> some View {
        modifier(LiquidGlassToolbarControlModifier(width: width))
    }

    /// Adds a glass card surface. Use this for grouped information, not for every text fragment.
    func liquidGlassCard(
        cornerRadius: CGFloat = LiquidGlass.CornerRadius.medium,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                isInteractive: isInteractive,
                fallbackElevation: 1
            )
        )
    }

    /// Applies a compact capsule surface to metadata such as scope and user-defined tags.
    /// Badges are informational, so they intentionally opt out of pointer interaction effects.
    func liquidGlassBadge(color: Color = .accentColor) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: LiquidGlass.CornerRadius.pill,
                tint: color.opacity(0.14),
                isInteractive: false,
                fallbackElevation: 0
            )
        )
    }

    /// Applies a responsive capsule surface to a custom plain button, such as a filter chip.
    func liquidGlassControl(tint: Color? = nil) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: LiquidGlass.CornerRadius.pill,
                tint: tint,
                isInteractive: true,
                fallbackElevation: 0.5
            )
        )
    }

    /// Applies the native glass button style while preserving a macOS 14-compatible fallback.
    func liquidGlassButtonStyle(
        _ prominence: LiquidGlass.ButtonProminence = .standard
    ) -> some View {
        modifier(LiquidGlassButtonStyleModifier(prominence: prominence))
    }
}
