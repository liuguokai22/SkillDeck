import Foundation

/// AgentVisibilitySettings manages which AI Agents are displayed in the sidebar navigation
///
/// By default, all supported agents are visible. Users can customize which agents are shown,
/// which is especially helpful for hiding agents that are not installed on the local machine.
/// Settings are persisted in UserDefaults via a comma-separated string of hidden agent raw values.
enum AgentVisibilitySettings {

    /// UserDefaults key for storing the comma-separated list of hidden agent identifiers
    static let hiddenAgentsKey = "agentVisibility.hiddenAgents"

    /// Check if a specific agent is visible in the sidebar
    /// - Parameters:
    ///   - agentType: The agent type to check
    ///   - hiddenRaw: The raw string of hidden agent IDs from UserDefaults
    /// - Returns: True if the agent should be shown in the sidebar
    static func isVisible(_ agentType: AgentType, hiddenRaw: String) -> Bool {
        let hiddenSet = parseHiddenSet(from: hiddenRaw)
        return !hiddenSet.contains(agentType.rawValue)
    }

    /// Set visibility for a specific agent
    /// - Parameters:
    ///   - visible: Whether the agent should be shown
    ///   - agentType: The agent type to update
    ///   - hiddenRaw: Inout reference to the raw string from UserDefaults
    static func setVisible(_ visible: Bool, for agentType: AgentType, hiddenRaw: inout String) {
        var hiddenSet = parseHiddenSet(from: hiddenRaw)
        if visible {
            hiddenSet.remove(agentType.rawValue)
        } else {
            hiddenSet.insert(agentType.rawValue)
        }
        hiddenRaw = hiddenSet.joined(separator: ",")
    }

    /// Toggle visibility for a specific agent
    static func toggleVisibility(_ agentType: AgentType, hiddenRaw: inout String) {
        let currentlyVisible = isVisible(agentType, hiddenRaw: hiddenRaw)
        setVisible(!currentlyVisible, for: agentType, hiddenRaw: &hiddenRaw)
    }

    /// Show all supported agents in the sidebar
    static func showAll(hiddenRaw: inout String) {
        hiddenRaw = ""
    }

    /// Show only agents that are detected as installed on the local machine
    /// - Parameters:
    ///   - installedAgents: The list of installed agents from SkillManager
    ///   - hiddenRaw: Inout reference to the raw string from UserDefaults
    static func showInstalledOnly(installedAgents: [Agent], hiddenRaw: inout String) {
        // An empty array means Agent detection has not completed yet. Preserve the user's current
        // visibility choices instead of briefly treating every supported Agent as uninstalled.
        guard !installedAgents.isEmpty else { return }

        let installedTypes = Set(installedAgents.filter(\.isAvailable).map(\.type.rawValue))
        let allTypes = Set(AgentType.allCases.map(\.rawValue))
        let toHide = allTypes.subtracting(installedTypes)
        hiddenRaw = toHide.joined(separator: ",")
    }

    /// Filter an array of agents to only those marked as visible
    static func visibleAgents(hiddenRaw: String) -> [AgentType] {
        AgentType.allCases.filter { isVisible($0, hiddenRaw: hiddenRaw) }
    }

    /// Helper to parse comma-separated string into a Set of strings
    private static func parseHiddenSet(from raw: String) -> Set<String> {
        Set(raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}
