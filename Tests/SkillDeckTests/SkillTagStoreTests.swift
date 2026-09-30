import XCTest
@testable import SkillDeck

final class SkillTagStoreTests: XCTestCase {

    var tempFileURL: URL!
    var tagStore: SkillTagStore!

    override func setUp() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillTagStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempFileURL = tempDir.appendingPathComponent(".skilldeck-tags.json")
        tagStore = SkillTagStore(fileURL: tempFileURL)
    }

    override func tearDown() async throws {
        if let tempDir = tempFileURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testAddTagAndGetTags() async throws {
        await tagStore.addTag("科研", to: "paper-reader")
        await tagStore.addTag("开发", to: "paper-reader")

        let tags = await tagStore.getTags(for: "paper-reader")
        XCTAssertEqual(tags, ["科研", "开发"])

        let knownTags = await tagStore.getAllKnownTags()
        XCTAssertTrue(knownTags.contains("科研"))
        XCTAssertTrue(knownTags.contains("开发"))
    }

    func testRemoveTag() async throws {
        await tagStore.addTag("科研", to: "paper-reader")
        await tagStore.addTag("求职", to: "paper-reader")

        await tagStore.removeTag("科研", from: "paper-reader")

        let tags = await tagStore.getTags(for: "paper-reader")
        XCTAssertEqual(tags, ["求职"])

        // Removing tag from a skill should not remove it from known tags
        let knownTags = await tagStore.getAllKnownTags()
        XCTAssertTrue(knownTags.contains("科研"))
    }

    func testSetTags() async throws {
        await tagStore.addTag("旧标签", to: "skill-1")
        await tagStore.setTags(for: "skill-1", tags: ["科研", "求职"])

        let tags = await tagStore.getTags(for: "skill-1")
        XCTAssertEqual(tags, ["科研", "求职"])

        let knownTags = await tagStore.getAllKnownTags()
        XCTAssertTrue(knownTags.contains("科研"))
        XCTAssertTrue(knownTags.contains("求职"))
        XCTAssertTrue(knownTags.contains("旧标签"))
    }

    func testRemoveKnownTagCascades() async throws {
        await tagStore.addTag("求职", to: "resume-helper")
        await tagStore.addTag("求职", to: "interview-prep")
        await tagStore.addTag("开发", to: "resume-helper")

        await tagStore.removeKnownTag("求职")

        let knownTags = await tagStore.getAllKnownTags()
        XCTAssertFalse(knownTags.contains("求职"))

        let resumeTags = await tagStore.getTags(for: "resume-helper")
        XCTAssertEqual(resumeTags, ["开发"])

        let interviewTags = await tagStore.getTags(for: "interview-prep")
        XCTAssertTrue(interviewTags.isEmpty)
    }

    func testSaveAndLoadPersistence() async throws {
        await tagStore.addTag("科研", to: "arxiv-search")
        await tagStore.addTag("求职", to: "linkedin-agent")
        await tagStore.addKnownTag("备用标签")
        try await tagStore.save()

        // Create new store pointing to same file
        let newStore = SkillTagStore(fileURL: tempFileURL)
        await newStore.load()

        let arxivTags = await newStore.getTags(for: "arxiv-search")
        XCTAssertEqual(arxivTags, ["科研"])

        let linkedinTags = await newStore.getTags(for: "linkedin-agent")
        XCTAssertEqual(linkedinTags, ["求职"])

        let knownTags = await newStore.getAllKnownTags()
        XCTAssertTrue(knownTags.contains("科研"))
        XCTAssertTrue(knownTags.contains("求职"))
        XCTAssertTrue(knownTags.contains("备用标签"))
    }

    func testNonExistentFileStartsEmpty() async throws {
        await tagStore.load()
        let tags = await tagStore.getTags(for: "non-existent")
        XCTAssertTrue(tags.isEmpty)
        let known = await tagStore.getAllKnownTags()
        XCTAssertTrue(known.isEmpty)
    }
}
