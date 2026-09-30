import SwiftUI

/// AgentToggleView displays installation status toggles for skill on each Agent (F06)
///
/// One Toggle per Agent (switch), creates symlink when on, deletes when off
/// Toggle for inherited installation (isInherited) shows as ON but disabled, with source hint
struct AgentToggleView: View {

    let skillID: String
    let viewModel: SkillDetailViewModel
    @Environment(SkillManager.self) private var skillManager

    var body: some View {
        VStack(spacing: 8) {
            // Iterate through all detected Agents
            ForEach(AgentType.allCases) { agentType in
                AgentToggleRow(
                    skillID: skillID,
                    agentType: agentType,
                    viewModel: viewModel
                )
            }
        }
    }
}

/// Single row for an Agent toggle
/// Uses skillID instead of Skill to ensure proper SwiftUI dependency tracking
private struct AgentToggleRow: View {
    let skillID: String
    let agentType: AgentType
    let viewModel: SkillDetailViewModel
    @Environment(SkillManager.self) private var skillManager

    /// Get the latest skill data from SkillManager to ensure real-time updates
    /// Accessing skillManager.skills here ensures SwiftUI tracks this dependency
    private var skill: Skill? {
        skillManager.skills.first { $0.id == skillID }
    }

    /// Find installation record for this Agent
    private var installation: SkillInstallation? {
        skill?.installations.first { $0.agentType == agentType }
    }

    /// Whether this Agent has the skill installed
    private var isInstalled: Bool {
        installation != nil
    }

    /// Check if this is an inherited installation (from another Agent's directory)
    private var isInherited: Bool {
        installation?.isTrulyInherited ?? false
    }

    /// Whether the Agent is available (installed or config exists)
    private var isAgentAvailable: Bool {
        let agent = skillManager.agents.first { $0.type == agentType }
        return agent?.isAvailable == true
    }

    /// Whether the toggle should be disabled
    private var isToggleDisabled: Bool {
        // Disabled conditions:
        // - Inherited installation (need to modify at source Agent)
        // - Agent not installed and skill not installed
        isInherited || (!isAgentAvailable && !isInstalled)
    }

    var body: some View {
        HStack {
            AgentBrandIcon(agentType: agentType, size: 19)
                .frame(width: 20)

            Text(agentType.displayName)

            Spacer()

            // Hint text for special states
            if isInherited, let installation {
                // Inherited installation: shows source path like "via ~/.claude/skills"
                Text("via \(installation.parentDirectoryDisplayPath)").appFont(.caption)
                    .foregroundStyle(.secondary)
            } else if !isAgentAvailable && !isInstalled {
                Text("Not installed").appFont(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { isInstalled },
                set: { _ in
                    Task {
                        // Pass the current skill from SkillManager, not the captured value
                        if let skill = skillManager.skills.first(where: { $0.id == skillID }) {
                            await viewModel.toggleAgent(agentType, for: skill)
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(isToggleDisabled)
        }
        .padding(.vertical, 2)
    }
}
