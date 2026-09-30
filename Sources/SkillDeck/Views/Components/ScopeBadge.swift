import SwiftUI

/// ScopeBadge displays the skill's scope badge
///
/// Three scopes have different colors and icons:
/// - Global (blue): shared global skill
/// - Local (gray): Agent local skill
/// - Project (green): project-level skill
struct ScopeBadge: View {

    let scope: SkillScope

    var body: some View {
        let color = Constants.ScopeColors.color(for: scope)
        HStack(spacing: 4) {
            Image(systemName: iconName).appFont(.caption2)
            Text(scope.displayName).appFont(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .frame(height: LiquidGlass.Metrics.metadataBadgeHeight)
        .foregroundStyle(color)
        .liquidGlassBadge(color: color)
    }

    private var iconName: String {
        switch scope {
        case .sharedGlobal: "globe"
        case .agentLocal: "person"
        case .project: "folder"
        }
    }
}
