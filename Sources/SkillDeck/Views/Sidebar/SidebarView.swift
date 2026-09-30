import SwiftUI

/// Sidebar navigation item enum
///
/// Each case represents a clickable item in the sidebar.
/// F09 adds `.registry` for browsing the skills.sh catalog.
enum SidebarItem: Hashable {
    case dashboard
    /// F09: Browse skills.sh catalog (leaderboard + search)
    case registry
    /// Browse the ClawHub marketplace for OpenClaw-compatible skills
    case clawHub
    case agent(AgentType)
    case settings

    /// Maps sidebar options to Agent filter values
    /// - .dashboard / .settings / .registry → nil (show all skills or different content)
    /// - .agent(type) → type (only show skills for this Agent)
    /// This computed property is similar to Java's getter, executes switch calculation on each access
    var agentFilter: AgentType? {
        switch self {
        case .agent(let agentType):
            return agentType
        case .dashboard, .settings, .registry, .clawHub:
            return nil
        }
    }
}

/// SidebarView is the app's sidebar navigation
///
/// macOS sidebar visual guidelines (referencing Finder, Mail and other native apps):
/// - Selected: rounded rectangle with accentColor semi-transparent background
/// - Hover: very light gray background, hinting it's clickable
/// - Normal: transparent background
///
/// @Binding is two-way binding (similar to Vue's v-model), parent and child components share the same state
struct SidebarView: View {

    @Binding var selection: SidebarItem?
    @Environment(SkillManager.self) private var skillManager

    /// @Environment reads custom font preferences from the environment values.
    @Environment(\.appFontFamily) private var appFontFamily
    @Environment(\.appFontBaseSize) private var appFontBaseSize

    @Environment(\.localizationBundle) private var localizationBundle
    @Environment(\.locale) private var locale
    @Environment(\.controlActiveState) private var controlActiveState

    /// Persisted comma-separated list of hidden agent raw values
    @AppStorage(AgentVisibilitySettings.hiddenAgentsKey) private var hiddenAgentsRaw: String = ""

    /// The fixed Settings row lives outside the scrolling List, so it owns a small hover state.
    @State private var isSettingsHovered = false

    private var sectionHeaderFont: Font {
        FontSettings.font(family: appFontFamily, baseSize: appFontBaseSize, textStyle: .caption)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Only the destinations and Agent filters scroll. Keeping Settings outside this List
            // makes it a stable bottom destination, matching Finder and Mail sidebars.
            List {
                // Section creates groups (shown as collapsible groups in macOS sidebar)
                Section {
                    sidebarRow(
                        item: .dashboard,
                        accessibilityLabel: L10n.string(L10nKeys.sidebarDashboard, bundle: localizationBundle, locale: locale),
                        badgeCount: skillManager.skills.isEmpty ? nil : skillManager.skills.count
                    ) {
                        Label {
                            LText(key: L10nKeys.sidebarDashboard)
                        } icon: {
                            Image(systemName: "square.grid.2x2")
                        }
                    }
                    // F09: Registry browser — browse and search skills.sh catalog
                    sidebarRow(
                        item: .registry,
                        accessibilityLabel: L10n.string(L10nKeys.sidebarRegistry, bundle: localizationBundle, locale: locale)
                    ) {
                        Label {
                            LText(key: L10nKeys.sidebarRegistry)
                        } icon: {
                            Image(systemName: "globe")
                        }
                    }

                    sidebarRow(
                        item: .clawHub,
                        accessibilityLabel: L10n.string(L10nKeys.sidebarClawHub, bundle: localizationBundle, locale: locale)
                    ) {
                        Label {
                            LText(key: L10nKeys.sidebarClawHub)
                        } icon: {
                            Image(systemName: "shippingbox")
                        }
                    }
                } header: {
                    LText(key: L10nKeys.sidebarSectionOverview)
                        .font(sectionHeaderFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section {
                    let visibleAgents = AgentVisibilitySettings.visibleAgents(hiddenRaw: hiddenAgentsRaw)
                    ForEach(visibleAgents) { agentType in
                        let agent = skillManager.agents.first { $0.type == agentType }
                        let skillCount = skillManager.skills(for: agentType).count

                        sidebarRow(
                            item: .agent(agentType),
                            accessibilityLabel: agentType.displayName,
                            badgeCount: skillCount == 0 ? nil : skillCount
                        ) {
                            Label {
                                Text(agentType.displayName)
                                    .fontWeight(selection == .agent(agentType) ? .semibold : .regular)
                            } icon: {
                                AgentBrandIcon(agentType: agentType, size: 19)
                            }
                        }
                        .opacity(agent?.isAvailable == true ? 1.0 : 0.5)
                        .contextMenu {
                            Button {
                                AgentVisibilitySettings.setVisible(false, for: agentType, hiddenRaw: &hiddenAgentsRaw)
                            } label: {
                                Label(
                                    L10n.string(L10nKeys.settingsAgentsHideAction, bundle: localizationBundle, locale: locale),
                                    systemImage: "eye.slash"
                                )
                            }
                        }
                    }
                } header: {
                    LText(key: L10nKeys.sidebarSectionAgents)
                        .font(sectionHeaderFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.sidebar)
            // The list's scroll background is hidden so every sidebar destination uses the same
            // slightly deeper semantic surface, including empty space below the last Agent.
            .scrollContentBackground(.hidden)
            .background(LiquidGlass.Surface.sidebar)

            Divider()
                .opacity(0.5)

            fixedSettingsRow
        }
        .background(LiquidGlass.Surface.sidebar.ignoresSafeArea())
        .navigationTitle(L10n.string(L10nKeys.appName, bundle: localizationBundle, locale: locale))
    }

    /// A non-scrolling Settings destination anchored to the bottom edge of the sidebar.
    ///
    /// This row intentionally uses one background only. The previous implementation layered a
    /// custom `listRowBackground` on top of the sidebar List's native selection material, which
    /// produced the darker rectangular patch visible in the reference screenshot.
    private var fixedSettingsRow: some View {
        let isSelected = selection == .settings
        let accessibilityLabel = L10n.string(
            L10nKeys.sidebarSettings,
            bundle: localizationBundle,
            locale: locale
        )

        return Button {
            selection = .settings
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .frame(width: 20)
                LText(key: L10nKeys.sidebarSettings)
                Spacer(minLength: 0)
            }
            .appFont(.body)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(sidebarForeground(isSelected: isSelected))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fixedSettingsBackground(isSelected: isSelected))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .accessibilityLabel(accessibilityLabel)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isSettingsHovered = isHovering
            }
        }
    }

    /// Reproduces the active/inactive native sidebar selection hierarchy for the fixed row.
    private func fixedSettingsBackground(isSelected: Bool) -> Color {
        if isSelected { return sidebarSelectionBackground(isSelected: true) }

        return isSettingsHovered ? Color.primary.opacity(0.06) : Color.clear
    }

    /// A single semantic selection fill shared by every navigation row.
    private func sidebarSelectionBackground(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return controlActiveState == .inactive
            ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
            : Color(nsColor: .selectedContentBackgroundColor)
    }

    /// Returns a readable label color for both active blue selection and inactive gray selection.
    private func sidebarForeground(isSelected: Bool) -> Color {
        guard isSelected else { return .secondary }
        return controlActiveState == .inactive ? .primary : .white
    }

    /// Build sidebar row view,统一 handling click, selection highlight and hover effects
    ///
    /// @ViewBuilder allows closure to return different View types (similar to Java's generic methods)
    /// `some View` is Swift's opaque return type,
    /// means "returns some View, but caller doesn't need to know the specific type"
    ///
    /// Implementation note: Uses `onTapGesture` instead of `Button` to avoid gesture conflicts
    /// with `List(selection:)`. List's native selection gesture can intercept Button tap events,
    /// causing intermittent unresponsiveness. Using `onTapGesture` with `contentShape(Rectangle())`
    /// ensures reliable click detection across the entire row.
    ///
    /// - Parameters:
    ///   - item: The sidebar item identifier used for selection state
    ///   - accessibilityLabel: Localized string for VoiceOver announcement (should match visible text)
    ///   - label: View builder closure providing the visible label content
    @ViewBuilder
    private func sidebarRow<Label: View>(
        item: SidebarItem,
        accessibilityLabel: String,
        badgeCount: Int? = nil,
        @ViewBuilder label: () -> Label
    ) -> some View {
        // Use HStack + Spacer to make content span full row width
        // Ensure click area and visual feedback cover entire row, not just text/icon area
        HStack(spacing: 0) {
            label()
                .appFont(.body)
            Spacer(minLength: 0)

            if let badgeCount {
                Text("\(badgeCount)")
                    .appFont(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(sidebarForeground(isSelected: selection == item))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background {
                        Capsule()
                            .fill(
                                selection == item
                                    ? Color.white.opacity(0.18)
                                    : Color.primary.opacity(0.07)
                            )
                    }
            }
        }
        // Horizontal padding keeps content appropriate distance from row edges, consistent with sidebar style
        .padding(.horizontal, 4)
        // Vertical padding ensures hover/selection background height matches macOS sidebar row height
        .padding(.vertical, 4)
        // Every row gets identical List insets. Counts are drawn inside this full-width container,
        // so Dashboard, Registry, ClawHub, and Agent selections share one highlight length.
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        // Remove default foreground styling - apply directly to label content instead
        .foregroundStyle(sidebarForeground(isSelected: selection == item))
        // .contentShape(Rectangle()) expands interaction area (click+hover) to entire row rectangle
        // Must be applied to container that already spans full width to take effect
        // Similar to CSS pointer-events: all + width: 100%
        .contentShape(Rectangle())
        // The List no longer owns selection rendering. Drawing exactly one background here fixes
        // the missing highlight without reintroducing the double-layer rectangle from the earlier
        // `List(selection:)` plus `listRowBackground` combination.
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(sidebarSelectionBackground(isSelected: selection == item))
        }
        // .onTapGesture handles click events - using this instead of Button to avoid
        // gesture conflicts with List(selection:) which can intercept Button taps
        .onTapGesture {
            selection = item
        }
        // Accessibility: Restore button semantics lost when replacing Button with HStack + onTapGesture
        // .accessibilityElement makes the entire row a single accessibility element (similar to Button behavior)
        // children: .combine merges child labels into a single announcement
        .accessibilityElement(children: .combine)
        // .accessibilityAddTraits(.isButton) announces this as a button to VoiceOver
        // This restores the control semantics that Button provided
        .accessibilityAddTraits(.isButton)
        // .accessibilityLabel provides the localized accessible name for the row
        // Uses the accessibilityLabel parameter which should match the visible localized text
        .accessibilityLabel(accessibilityLabel)
        // .accessibilityInputLabels allows users to navigate by typing the item name
        // Uses the same localized accessibilityLabel for consistency
        .accessibilityInputLabels([accessibilityLabel])
    }
}
