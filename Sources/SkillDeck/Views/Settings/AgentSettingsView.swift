import SwiftUI

/// AgentSettingsView allows users to configure which Agents are displayed in the sidebar navigation
///
/// Especially useful when users have only a few AI Agents installed locally,
/// allowing them to hide unused agents to keep the sidebar uncluttered.
struct AgentSettingsView: View {

    @Environment(SkillManager.self) private var skillManager
    @Environment(\.localizationBundle) private var localizationBundle
    @Environment(\.locale) private var locale

    /// Persisted comma-separated list of hidden agent raw values
    @AppStorage(AgentVisibilitySettings.hiddenAgentsKey) private var hiddenAgentsRaw: String = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LText(key: L10nKeys.settingsAgentsSectionSubtitle)
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            AgentVisibilitySettings.showAll(hiddenRaw: &hiddenAgentsRaw)
                        } label: {
                            Label(
                                L10n.string(L10nKeys.settingsAgentsShowAll, bundle: localizationBundle, locale: locale),
                                systemImage: "eye"
                            )
                        }
                        .liquidGlassButtonStyle()
                        .controlSize(.small)

                        Button {
                            AgentVisibilitySettings.showInstalledOnly(
                                installedAgents: skillManager.agents,
                                hiddenRaw: &hiddenAgentsRaw
                            )
                        } label: {
                            Label(
                                L10n.string(L10nKeys.settingsAgentsShowInstalledOnly, bundle: localizationBundle, locale: locale),
                                systemImage: "checkmark.circle"
                            )
                        }
                        .liquidGlassButtonStyle()
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                LText(key: L10nKeys.settingsAgentsSectionTitle)
            }

            Section {
                ForEach(AgentType.allCases, id: \.self) { agentType in
                    let agent = skillManager.agents.first { $0.type == agentType }
                    let isInstalled = agent?.isAvailable == true
                    let skillCount = skillManager.skills(for: agentType).count
                    let isVisible = AgentVisibilitySettings.isVisible(agentType, hiddenRaw: hiddenAgentsRaw)

                    HStack(spacing: 12) {
                        AgentBrandIcon(agentType: agentType, size: 24)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(agentType.displayName)
                                    .appFont(.body)
                                    .fontWeight(.medium)

                                // Installed status badge
                                if isInstalled {
                                    Text(L10n.string(L10nKeys.settingsAgentsInstalledBadge, bundle: localizationBundle, locale: locale))
                                        .appFont(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(Color.green)
                                        .clipShape(Capsule())
                                } else {
                                    Text(L10n.string(L10nKeys.settingsAgentsNotInstalledBadge, bundle: localizationBundle, locale: locale))
                                        .appFont(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.12))
                                        .foregroundStyle(Color.secondary)
                                        .clipShape(Capsule())
                                }
                            }

                            Text("\(skillCount) skills • \(agentType.skillsDirectoryPath)")
                                .appFont(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { isVisible },
                            set: { newValue in
                                AgentVisibilitySettings.setVisible(newValue, for: agentType, hiddenRaw: &hiddenAgentsRaw)
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Toggling off an agent hides it from the sidebar navigation. Installed skills for that agent remain unaffected.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(LiquidGlass.Surface.content)
        .padding()
        .navigationTitle(L10n.string(L10nKeys.settingsTabAgents, bundle: localizationBundle, locale: locale))
    }
}
