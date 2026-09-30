import XCTest
@testable import SkillDeck

final class AgentVisibilitySettingsTests: XCTestCase {

    func testDefaultAllAgentsVisible() {
        let raw = ""
        for agentType in AgentType.allCases {
            XCTAssertTrue(AgentVisibilitySettings.isVisible(agentType, hiddenRaw: raw))
        }
        XCTAssertEqual(AgentVisibilitySettings.visibleAgents(hiddenRaw: raw).count, AgentType.allCases.count)
    }

    func testHideSpecificAgent() {
        var raw = ""
        AgentVisibilitySettings.setVisible(false, for: .claudeCode, hiddenRaw: &raw)

        XCTAssertFalse(AgentVisibilitySettings.isVisible(.claudeCode, hiddenRaw: raw))
        XCTAssertTrue(AgentVisibilitySettings.isVisible(.codex, hiddenRaw: raw))

        let visible = AgentVisibilitySettings.visibleAgents(hiddenRaw: raw)
        XCTAssertFalse(visible.contains(.claudeCode))
        XCTAssertTrue(visible.contains(.codex))
        XCTAssertEqual(visible.count, AgentType.allCases.count - 1)
    }

    func testUnhideAgent() {
        var raw = "claude-code,codex"
        XCTAssertFalse(AgentVisibilitySettings.isVisible(.claudeCode, hiddenRaw: raw))
        XCTAssertFalse(AgentVisibilitySettings.isVisible(.codex, hiddenRaw: raw))

        AgentVisibilitySettings.setVisible(true, for: .claudeCode, hiddenRaw: &raw)
        XCTAssertTrue(AgentVisibilitySettings.isVisible(.claudeCode, hiddenRaw: raw))
        XCTAssertFalse(AgentVisibilitySettings.isVisible(.codex, hiddenRaw: raw))
    }

    func testShowAllClearsHidden() {
        var raw = "claude-code,codex,gemini-cli"
        AgentVisibilitySettings.showAll(hiddenRaw: &raw)
        XCTAssertEqual(raw, "")
        for agentType in AgentType.allCases {
            XCTAssertTrue(AgentVisibilitySettings.isVisible(agentType, hiddenRaw: raw))
        }
    }

    func testShowInstalledOnly() {
        var raw = ""
        let installedAgent = Agent(
            type: .codex,
            isInstalled: true,
            configDirectoryExists: true,
            skillsDirectoryExists: true,
            skillCount: 3
        )
        let uninstalledAgent = Agent(
            type: .claudeCode,
            isInstalled: false,
            configDirectoryExists: false,
            skillsDirectoryExists: false,
            skillCount: 0
        )

        AgentVisibilitySettings.showInstalledOnly(
            installedAgents: [installedAgent, uninstalledAgent],
            hiddenRaw: &raw
        )

        XCTAssertTrue(AgentVisibilitySettings.isVisible(.codex, hiddenRaw: raw))
        XCTAssertFalse(AgentVisibilitySettings.isVisible(.claudeCode, hiddenRaw: raw))
    }

    func testShowInstalledOnlyUsesConfigurationDirectoryWhenGUIPathCannotFindCLI() {
        var raw = ""
        let configOnlyAgent = Agent(
            type: .claudeCode,
            isInstalled: false,
            configDirectoryExists: true,
            skillsDirectoryExists: false,
            skillCount: 0
        )
        let unavailableAgent = Agent(
            type: .qoder,
            isInstalled: false,
            configDirectoryExists: false,
            skillsDirectoryExists: false,
            skillCount: 0
        )

        AgentVisibilitySettings.showInstalledOnly(
            installedAgents: [configOnlyAgent, unavailableAgent],
            hiddenRaw: &raw
        )

        XCTAssertTrue(AgentVisibilitySettings.isVisible(.claudeCode, hiddenRaw: raw))
        XCTAssertFalse(AgentVisibilitySettings.isVisible(.qoder, hiddenRaw: raw))
    }

    func testShowInstalledOnlyUsesSkillsDirectoryAsInstallationEvidence() {
        var raw = ""
        let skillsOnlyAgent = Agent(
            type: .codex,
            isInstalled: false,
            configDirectoryExists: false,
            skillsDirectoryExists: true,
            skillCount: 1
        )

        AgentVisibilitySettings.showInstalledOnly(
            installedAgents: [skillsOnlyAgent],
            hiddenRaw: &raw
        )

        XCTAssertTrue(AgentVisibilitySettings.isVisible(.codex, hiddenRaw: raw))
    }

    func testShowInstalledOnlyBeforeDetectionPreservesCurrentVisibility() {
        var raw = "claude-code"

        AgentVisibilitySettings.showInstalledOnly(installedAgents: [], hiddenRaw: &raw)

        XCTAssertEqual(raw, "claude-code")
    }
}
