import XCTest
@testable import SkillDeck

@MainActor
final class DashboardTagFilterTests: XCTestCase {

    var skillManager: SkillManager!
    var viewModel: DashboardViewModel!

    private func makeSkill(
        id: String,
        name: String? = nil,
        description: String = "",
        installations: [SkillInstallation] = []
    ) -> Skill {
        Skill(
            id: id,
            canonicalURL: URL(fileURLWithPath: "/tmp/test-skills/\(id)"),
            metadata: SkillMetadata(name: name ?? id, description: description),
            markdownBody: "",
            scope: .sharedGlobal,
            installations: installations
        )
    }

    override func setUp() async throws {
        skillManager = SkillManager()
        viewModel = DashboardViewModel(skillManager: skillManager)

        let skillA = makeSkill(id: "paper-summarizer", name: "Paper Summarizer", description: "Summarize academic papers")
        let skillB = makeSkill(id: "job-hunter", name: "Job Hunter", description: "Search for tech jobs")
        let skillC = makeSkill(id: "code-reviewer", name: "Code Reviewer", description: "Review pull requests")

        skillManager.skills = [skillA, skillB, skillC]

        // Assign tags
        skillManager.skillTags = [
            "paper-summarizer": ["科研"],
            "job-hunter": ["求职"],
            "code-reviewer": ["科研", "开发"]
        ]
        skillManager.knownTags = ["科研", "求职", "开发"]
    }

    func testNoFilterReturnsAllSkills() {
        viewModel.selectedTagFilter = nil
        XCTAssertEqual(viewModel.filteredSkills.count, 3)
    }

    func testFilterByResearchTag() {
        viewModel.selectedTagFilter = "科研"
        let filtered = viewModel.filteredSkills
        XCTAssertEqual(filtered.count, 2)
        let ids = Set(filtered.map(\.id))
        XCTAssertEqual(ids, ["paper-summarizer", "code-reviewer"])
    }

    func testFilterByJobSeekingTag() {
        viewModel.selectedTagFilter = "求职"
        let filtered = viewModel.filteredSkills
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "job-hunter")
    }

    func testFilterByNonExistentTag() {
        viewModel.selectedTagFilter = "不存在的标签"
        let filtered = viewModel.filteredSkills
        XCTAssertTrue(filtered.isEmpty)
    }

    func testFilterByTagCombinedWithSearch() {
        viewModel.selectedTagFilter = "科研"
        viewModel.searchText = "Reviewer"

        let filtered = viewModel.filteredSkills
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "code-reviewer")
    }

    func testClearTagFilterRestoresSkills() {
        viewModel.selectedTagFilter = "求职"
        XCTAssertEqual(viewModel.filteredSkills.count, 1)

        viewModel.selectedTagFilter = nil
        XCTAssertEqual(viewModel.filteredSkills.count, 3)
    }
}
